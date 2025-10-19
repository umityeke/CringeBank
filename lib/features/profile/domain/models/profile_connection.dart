import 'package:equatable/equatable.dart';

class ProfileConnection extends Equatable {
  const ProfileConnection({
    required this.id,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.relation,
  });

  final String id;
  final String displayName;
  final String handle;
  final String avatarUrl;
  final String relation;

  @override
  List<Object?> get props => [id, displayName, handle, avatarUrl, relation];
}
