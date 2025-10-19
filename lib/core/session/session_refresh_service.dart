import 'session_bootstrap.dart';

abstract class SessionRefreshCoordinator {
  const SessionRefreshCoordinator();

  void registerSession({
    required String identifier,
    required SessionBootstrapData session,
  });

  Future<void> forceRefresh();

  void clear();

  void dispose();
}

class NoopSessionRefreshCoordinator extends SessionRefreshCoordinator {
  const NoopSessionRefreshCoordinator();

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
