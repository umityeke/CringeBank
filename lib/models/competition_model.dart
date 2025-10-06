import 'package:cloud_firestore/cloud_firestore.dart';

/// Yarışma tipleri
enum CompetitionType {
  prediction, // Tahmin yarışması
  vote, // Oylama
  quiz, // Quiz/Bilgi yarışması
  upload, // Upload yarışması (foto/video)
  tournament, // Turnuva (ileride)
}

/// Yarışma durumu (state machine: draft → live → finished → archived)
enum CompetitionStatus {
  draft, // Taslak (görünmez)
  live, // Aktif (katılım açık)
  finished, // Bitmiş (kazanan belirlendi)
  archived, // Arşivlenmiş
}

/// Yarışma görünürlüğü
enum CompetitionVisibility {
  public_, // Herkese açık
  private_, // Sadece adminler görür
}

/// Yarışma ödülü
class CompetitionPrize {
  final String currency; // Genelde "CG"
  final double amount;

  const CompetitionPrize({required this.currency, required this.amount});

  factory CompetitionPrize.fromJson(Map<String, dynamic> json) {
    return CompetitionPrize(
      currency: json['currency'] as String? ?? 'CG',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'currency': currency, 'amount': amount};
  }

  @override
  String toString() => '$amount $currency';
}

/// Ana yarışma modeli
class Competition {
  final String id;
  final String title;
  final String? description;
  final String categoryId;
  final String? subCategoryId;
  final CompetitionType type;
  final CompetitionStatus status;
  final DateTime startAt;
  final DateTime endAt;
  final CompetitionVisibility visibility;
  final DateTime createdAt;
  final String createdBy;
  final CompetitionPrize prize;
  final int? entryLimitPerUser;
  final bool requiresApproval; // Upload yarışmalarında entry onayı gerekli mi?
  final Map<String, dynamic>? options; // Vote/Quiz seçenekleri
  final int participantCount;
  final int totalVotes;
  final String? winnerId; // Kazanan uid

  const Competition({
    required this.id,
    required this.title,
    this.description,
    required this.categoryId,
    this.subCategoryId,
    required this.type,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.visibility,
    required this.createdAt,
    required this.createdBy,
    required this.prize,
    this.entryLimitPerUser,
    required this.requiresApproval,
    this.options,
    required this.participantCount,
    required this.totalVotes,
    this.winnerId,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      categoryId: json['categoryId'] as String,
      subCategoryId: json['subCategoryId'] as String?,
      type: _parseType(json['type']),
      status: _parseStatus(json['status']),
      startAt: _parseTimestamp(json['startAt']),
      endAt: _parseTimestamp(json['endAt']),
      visibility: _parseVisibility(json['visibility']),
      createdAt: _parseTimestamp(json['createdAt']),
      createdBy: json['createdBy'] as String,
      prize: CompetitionPrize.fromJson(
        json['prize'] as Map<String, dynamic>? ?? {},
      ),
      entryLimitPerUser: (json['entryLimitPerUser'] as num?)?.toInt(),
      requiresApproval: json['requiresApproval'] as bool? ?? false,
      options: json['options'] as Map<String, dynamic>?,
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
      winnerId: json['winnerId'] as String?,
    );
  }

  factory Competition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Competition.fromJson(data);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'categoryId': categoryId,
      if (subCategoryId != null) 'subCategoryId': subCategoryId,
      'type': type.name,
      'status': status.name,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'visibility': visibility == CompetitionVisibility.public_
          ? 'public'
          : 'private',
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'prize': prize.toJson(),
      if (entryLimitPerUser != null) 'entryLimitPerUser': entryLimitPerUser,
      'requiresApproval': requiresApproval,
      if (options != null) 'options': options,
      'participantCount': participantCount,
      'totalVotes': totalVotes,
      if (winnerId != null) 'winnerId': winnerId,
    };
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  Competition copyWith({
    String? id,
    String? title,
    String? description,
    String? categoryId,
    String? subCategoryId,
    CompetitionType? type,
    CompetitionStatus? status,
    DateTime? startAt,
    DateTime? endAt,
    CompetitionVisibility? visibility,
    DateTime? createdAt,
    String? createdBy,
    CompetitionPrize? prize,
    int? entryLimitPerUser,
    bool? requiresApproval,
    Map<String, dynamic>? options,
    int? participantCount,
    int? totalVotes,
    String? winnerId,
  }) {
    return Competition(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      type: type ?? this.type,
      status: status ?? this.status,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      prize: prize ?? this.prize,
      entryLimitPerUser: entryLimitPerUser ?? this.entryLimitPerUser,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      options: options ?? this.options,
      participantCount: participantCount ?? this.participantCount,
      totalVotes: totalVotes ?? this.totalVotes,
      winnerId: winnerId ?? this.winnerId,
    );
  }

  bool get isLive => status == CompetitionStatus.live;
  bool get isFinished => status == CompetitionStatus.finished;
  bool get isDraft => status == CompetitionStatus.draft;
  bool get isArchived => status == CompetitionStatus.archived;

  bool get isActive {
    final now = DateTime.now();
    return status == CompetitionStatus.live &&
        now.isAfter(startAt) &&
        now.isBefore(endAt);
  }

  static CompetitionType _parseType(dynamic value) {
    if (value == null) return CompetitionType.upload;
    if (value is CompetitionType) return value;
    final str = value.toString();
    return CompetitionType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => CompetitionType.upload,
    );
  }

  static CompetitionStatus _parseStatus(dynamic value) {
    if (value == null) return CompetitionStatus.draft;
    if (value is CompetitionStatus) return value;
    final str = value.toString();
    return CompetitionStatus.values.firstWhere(
      (e) => e.name == str,
      orElse: () => CompetitionStatus.draft,
    );
  }

  static CompetitionVisibility _parseVisibility(dynamic value) {
    if (value == null) return CompetitionVisibility.public_;
    if (value is CompetitionVisibility) return value;
    final str = value.toString();
    return str == 'public'
        ? CompetitionVisibility.public_
        : CompetitionVisibility.private_;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  String toString() =>
      'Competition(id: $id, title: $title, type: ${type.name}, status: ${status.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Competition &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
