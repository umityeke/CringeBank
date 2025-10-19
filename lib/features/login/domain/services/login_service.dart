import '../models/login_models.dart';

export '../models/login_models.dart' show LoginAccountRole;

class LoginException implements Exception {
  LoginException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'LoginException(code: $code, message: $message)';
}

class LoginResult {
  LoginResult({
    required this.requiresMfa,
    required this.availableChannels,
    required this.requiresVerification,
    Set<LoginAccountRole>? roles,
  }) : roles = Set<LoginAccountRole>.unmodifiable(
          roles ?? const {LoginAccountRole.user},
        );

  final bool requiresMfa;
  final List<MfaChannel> availableChannels;
  final bool requiresVerification;
  final Set<LoginAccountRole> roles;
}

class PasskeyChallenge {
  const PasskeyChallenge({
    required this.challengeId,
    required this.rpId,
    required this.userId,
    required this.timeout,
  });

  final String challengeId;
  final String rpId;
  final String userId;
  final Duration timeout;
}

abstract class LoginService {
  Future<LoginResult> authenticate({
    required LoginMethod method,
    required String identifier,
    required String password,
    required CredentialsForm credentials,
    required DeviceInfo deviceInfo,
    required SessionMetadata session,
  });

  Future<List<MfaChannel>> fetchAvailableMfaChannels(String identifier);

  Future<void> sendOtp({
    required String identifier,
    required MfaChannel channel,
  });

  Future<String> sendMagicLink({
    required String identifier,
  });

  Future<void> verifyMagicLink({
    required String token,
    required String identifier,
  });

  Future<String> requestPasswordReset({
    required String identifier,
  });

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> verifyOtp({
    required String identifier,
    required String code,
    required MfaChannel channel,
  });

  Future<void> verifyTotp({
    required String identifier,
    required String code,
  });

  Future<PasskeyChallenge> createPasskeyChallenge({
    required String identifier,
    required DeviceInfo deviceInfo,
  });

  Future<void> verifyPasskeyAssertion({
    required String identifier,
    required String challengeId,
    required String clientDataJson,
    required String authenticatorData,
    required String signature,
  });

  Future<void> recordSuccessfulLogin({
    required String identifier,
    required SessionMetadata session,
  });

  Future<void> recordFailedAttempt({
    required String identifier,
    required SessionMetadata session,
    required String reason,
  });

  Future<LockInfo?> getLockInfo(String identifier);

  Future<void> clearLock(String identifier);
}
