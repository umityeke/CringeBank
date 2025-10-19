import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../sources/mock_profile_source.dart';

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._source);

  final MockProfileSource _source;

  @override
  Stream<UserProfile> watchMyProfile() => _source.watchProfile();
}
