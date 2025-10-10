import 'package:cloud_firestore/cloud_firestore.dart';

class SpecialProjectConfig {
  final String id;
  final String title;
  final String description;
  final int priority;
  final String? imageUrl;
  final bool isEnabled;

  const SpecialProjectConfig({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.isEnabled,
    this.imageUrl,
  });

  factory SpecialProjectConfig.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return SpecialProjectConfig(
      id: doc.id,
      title: _readString(data['title']) ?? 'Special Project',
      description: _readString(data['description']) ?? '',
      priority: _readPriority(data['priority']),
      imageUrl: _readString(data['image_url']),
      isEnabled: data['enabled'] == true,
    );
  }

  static String? _readString(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static int _readPriority(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }
}
