import 'package:cloud_firestore/cloud_firestore.dart';

/// Upload yarışma entry durumu
enum EntryStatus {
  pending, // Onay bekliyor
  approved, // Onaylandı (herkese görünür)
  rejected, // Reddedildi
}

/// Upload yarışması katılımı (entries subcollection)
class CompetitionEntry {
  final String id; // Entry ID (genelde ownerId ile aynı - kişi başı 1)
  final String competitionId;
  final String ownerId;
  final String? caption;
  final List<String> mediaRefs; // Storage paths
  final EntryStatus status;
  final DateTime createdAt;
  final int votes; // Kaç kişi oy verdi

  const CompetitionEntry({
    required this.id,
    required this.competitionId,
    required this.ownerId,
    this.caption,
    required this.mediaRefs,
    required this.status,
    required this.createdAt,
    required this.votes,
  });

  factory CompetitionEntry.fromJson(
    Map<String, dynamic> json, {
    required String competitionId,
  }) {
    return CompetitionEntry(
      id: json['id'] as String,
      competitionId: competitionId,
      ownerId: json['ownerId'] as String,
      caption: json['caption'] as String?,
      mediaRefs:
          (json['mediaRefs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: _parseStatus(json['status']),
      createdAt: _parseTimestamp(json['createdAt']),
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );
  }

  factory CompetitionEntry.fromFirestore(
    DocumentSnapshot doc, {
    required String competitionId,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return CompetitionEntry.fromJson(data, competitionId: competitionId);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      if (caption != null && caption!.isNotEmpty) 'caption': caption,
      'mediaRefs': mediaRefs,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'votes': votes,
    };
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  CompetitionEntry copyWith({
    String? id,
    String? competitionId,
    String? ownerId,
    String? caption,
    List<String>? mediaRefs,
    EntryStatus? status,
    DateTime? createdAt,
    int? votes,
  }) {
    return CompetitionEntry(
      id: id ?? this.id,
      competitionId: competitionId ?? this.competitionId,
      ownerId: ownerId ?? this.ownerId,
      caption: caption ?? this.caption,
      mediaRefs: mediaRefs ?? this.mediaRefs,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      votes: votes ?? this.votes,
    );
  }

  bool get isPending => status == EntryStatus.pending;
  bool get isApproved => status == EntryStatus.approved;
  bool get isRejected => status == EntryStatus.rejected;

  static EntryStatus _parseStatus(dynamic value) {
    if (value == null) return EntryStatus.pending;
    if (value is EntryStatus) return value;
    final str = value.toString();
    return EntryStatus.values.firstWhere(
      (e) => e.name == str,
      orElse: () => EntryStatus.pending,
    );
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
      'CompetitionEntry(id: $id, ownerId: $ownerId, status: ${status.name}, votes: $votes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompetitionEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          competitionId == other.competitionId;

  @override
  int get hashCode => Object.hash(id, competitionId);
}
