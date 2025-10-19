import 'package:equatable/equatable.dart';

enum ProfileActivityType {
  post,
  sale,
  badge,
}

class ProfileActivity extends Equatable {
  const ProfileActivity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final ProfileActivityType type;

  @override
  List<Object?> get props => [id, title, subtitle, timestamp, type];
}
