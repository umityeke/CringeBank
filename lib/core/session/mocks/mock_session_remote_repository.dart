import '../session_remote_repository.dart';

class MockSessionRemoteRepository implements SessionRemoteRepository {
  int registerCalls = 0;
  int revokeCalls = 0;
  SessionLoginContext? lastContext;
  String? lastIdentifier;
  bool requiresVerification = false;

  @override
  Future<SessionRegistrationOutcome> registerDeviceLogin({
    required String identifier,
    required SessionLoginContext context,
  }) async {
    registerCalls += 1;
    lastIdentifier = identifier;
    lastContext = context;
    return SessionRegistrationOutcome(
      requiresDeviceVerification: requiresVerification,
    );
  }

  @override
  Future<void> revokeAllSessions({required String identifier}) async {
    revokeCalls += 1;
    lastIdentifier = identifier;
  }
}
