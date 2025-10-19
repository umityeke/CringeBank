import 'package:equatable/equatable.dart';

enum ProfileSocialPlatform {
  tiktok,
  youtube,
  instagram,
  website,
}

class ProfileSocialLink extends Equatable {
  const ProfileSocialLink({
    required this.id,
    required this.label,
    required this.url,
    required this.platform,
  });

  final String id;
  final String label;
  final String url;
  final ProfileSocialPlatform platform;

  @override
  List<Object?> get props => [id, label, url, platform];
}
