import 'package:cloud_firestore/cloud_firestore.dart';

/// Yarışma kategorisi modeli
/// Örnek: "Fotoğraf", "Video", "Yazı", "Sanat" vs.
class CompetitionCategory {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int order;
  final bool isActive;
  final DateTime createdAt;

  const CompetitionCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.order,
    required this.isActive,
    required this.createdAt,
  });

  factory CompetitionCategory.fromJson(Map<String, dynamic> json) {
    return CompetitionCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  factory CompetitionCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompetitionCategory(
      id: doc.id,
      name: data['name'] as String,
      description: data['description'] as String?,
      iconUrl: data['iconUrl'] as String?,
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'order': order,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id'); // Firestore ID'yi dışarıda tutar
    return json;
  }

  CompetitionCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    int? order,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CompetitionCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
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
      'CompetitionCategory(id: $id, name: $name, order: $order)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompetitionCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
