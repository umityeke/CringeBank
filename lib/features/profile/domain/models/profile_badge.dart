import 'package:equatable/equatable.dart';

class ProfileBadge extends Equatable {
  const ProfileBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final String icon;

  @override
  List<Object?> get props => [id, name, description, icon];
}
