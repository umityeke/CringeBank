import '../session_bootstrap.dart';
import '../session_refresh_service.dart';

class MockSessionRefreshCoordinator extends SessionRefreshCoordinator {
  MockSessionRefreshCoordinator();

  @override
  void registerSession({
    required String identifier,
    required SessionBootstrapData session,
  }) {}

  @override
  Future<void> forceRefresh() async {}

  @override
  void clear() {}

  @override
  void dispose() {}
}
