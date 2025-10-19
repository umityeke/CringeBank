import '../models/user_profile.dart';

abstract class ProfileRepository {
  Stream<UserProfile> watchMyProfile();
}
