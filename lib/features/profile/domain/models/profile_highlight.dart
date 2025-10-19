import 'package:equatable/equatable.dart';

enum ProfileHighlightType {
  trophy,
  trending,
  lightning,
}

class ProfileHighlight extends Equatable {
  const ProfileHighlight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
  });

  final String id;
  final String title;
  final String description;
  final ProfileHighlightType type;

  @override
  List<Object?> get props => [id, title, description, type];
}
