import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/service_locator.dart';
import 'domain/models/user_profile.dart';
import 'domain/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => sl<ProfileRepository>());

final myProfileProvider = StreamProvider<UserProfile>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchMyProfile();
});
