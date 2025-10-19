class SessionLoginContext {
  const SessionLoginContext({
    required this.deviceIdHash,
    required this.ipHash,
    required this.userAgent,
    required this.locale,
    required this.timeZone,
  });

  final String deviceIdHash;
  final String ipHash;
  final String userAgent;
  final String locale;
  final String timeZone;
}

class SessionRegistrationOutcome {
  const SessionRegistrationOutcome({required this.requiresDeviceVerification});

  final bool requiresDeviceVerification;
}

abstract class SessionRemoteRepository {
  Future<SessionRegistrationOutcome> registerDeviceLogin({
    required String identifier,
    required SessionLoginContext context,
  });

  Future<void> revokeAllSessions({required String identifier});
}
