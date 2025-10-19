import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/cringestore_repository.dart';
import '../../features/feed/data/feed_api_config.dart';
import '../../features/feed/data/hybrid_feed_repository.dart';
import '../../features/feed/data/remote_feed_repository.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/login/data/login_audit_service.dart';
import '../../features/login/data/login_local_storage.dart';
import '../../features/login/data/mocks/mock_login_service.dart';
import '../../features/login/domain/services/login_service.dart';
import '../../features/profile/data/repositories/mock_profile_repository.dart';
import '../../features/profile/data/repositories/mock_tag_approval_repository.dart';
import '../../features/profile/data/sources/mock_profile_source.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/repositories/tag_approval_repository.dart';
import '../session/firebase_session_refresh_coordinator.dart';
import '../session/device_fingerprint_controller.dart';
import '../session/device_fingerprint_storage.dart';
import '../session/mocks/mock_session_remote_repository.dart';
import '../session/session_controller.dart';
import '../session/session_local_storage.dart';
import '../session/session_remote_repository.dart';
import '../session/session_refresh_service.dart';
import '../telemetry/mocks/mock_telemetry_service.dart';
import '../telemetry/telemetry_service.dart';
import '../../services/cringe_store_service.dart';
import '../../services/tagging_policy_service.dart';

final sl = GetIt.instance;

var _isConfigured = false;

Future<void> configureDependencies({
  SharedPreferences? sharedPreferences,
}) async {
  if (_isConfigured) {
    return;
  }

  final prefs = sharedPreferences ?? await SharedPreferences.getInstance();

  _isConfigured = true;

  sl
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerLazySingleton<LoginLocalStorage>(
      () => SharedPreferencesLoginLocalStorage(sl()),
    )
    ..registerLazySingleton<FeedApiConfig>(FeedApiConfig.new)
    ..registerLazySingleton<RemoteFeedRepository>(
      () => RemoteFeedRepository(
        config: sl(),
      ),
    )
    ..registerLazySingleton<LoginAuditService>(LoginAuditService.new)
    ..registerLazySingleton<SessionLocalStorage>(
      () => SharedPreferencesSessionLocalStorage(sl()),
    )
    ..registerLazySingleton<DeviceFingerprintStorage>(
      () => SharedPreferencesDeviceFingerprintStorage(sl()),
    )
    ..registerLazySingleton<SessionRefreshCoordinator>(
      () => FirebaseSessionRefreshCoordinator(
        sessionController: sl(),
      ),
      dispose: (coordinator) => coordinator.dispose(),
    )
    ..registerLazySingleton<MockProfileSource>(MockProfileSource.new)
    ..registerLazySingleton<ProfileRepository>(
      () => MockProfileRepository(sl()),
    )
    ..registerLazySingleton<TagApprovalRepository>(
      MockTagApprovalRepository.new,
      dispose: (repository) => repository.dispose(),
    )
    ..registerLazySingleton<LoginService>(MockLoginService.new)
    ..registerLazySingleton<TelemetryService>(MockTelemetryService.new)
    ..registerLazySingleton<SessionRemoteRepository>(
      MockSessionRemoteRepository.new,
    )
    ..registerLazySingleton<SessionController>(
      () => SessionController(storage: sl(), remote: sl(), telemetry: sl()),
    )
    ..registerLazySingleton<DeviceFingerprintController>(
      () => DeviceFingerprintController(storage: sl()),
      dispose: (controller) => controller.dispose(),
    )
    ..registerLazySingleton<FeedRepository>(
      () => HybridFeedRepository(
        remote: sl(),
        config: sl(),
      ),
    )
    ..registerLazySingleton<TaggingPolicyService>(
      () => TaggingPolicyService.instance,
    )
    ..registerLazySingleton<CringeStoreService>(CringeStoreService.new)
    ..registerLazySingleton<CringeStoreRepository>(
      () => CringeStoreRepository(storeService: sl()),
    );
}

Future<void> resetDependencies() async {
  await sl.reset(dispose: true);
  _isConfigured = false;
}

