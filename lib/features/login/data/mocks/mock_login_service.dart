import '../../domain/models/login_models.dart';
import '../../domain/services/login_service.dart';

class MockLoginService implements LoginService {
  MockLoginService();

  final Map<String, int> _failedAttempts = {};
  final Map<String, LockInfo> _locks = {};
  final Map<String, List<MfaChannel>> _userMfaChannels = {};
  final Set<String> _requiresVerification = {};
  final Map<String, String> _passwordResetTokens = {};
  final Map<String, Set<LoginAccountRole>> _roles = {};
  int authenticateCalls = 0;

  @override
  Future<LoginResult> authenticate({
    required LoginMethod method,
    required String identifier,
    required String password,
    required CredentialsForm credentials,
    required DeviceInfo deviceInfo,
    required SessionMetadata session,
  }) async {
    authenticateCalls += 1;
    final lock = await getLockInfo(identifier);
    if (lock != null && lock.until.isAfter(DateTime.now())) {
      throw LoginException('Hesabın geçici olarak kilitlendi.', code: 'locked');
    }

    if (password != 'CorrectPass123!') {
      throw LoginException('Kullanıcı adı veya parola hatalı.', code: 'invalid_credentials');
    }

    await clearLock(identifier);

    final requiresMfa = _userMfaChannels.containsKey(identifier);
    final channels = _userMfaChannels[identifier] ?? const [];
    final requiresVerification = _requiresVerification.contains(identifier);

    final roles = _roles[identifier];
    return LoginResult(
      requiresMfa: requiresMfa,
      availableChannels: channels,
      requiresVerification: requiresVerification,
      roles: roles,
    );
  }

  @override
  Future<void> clearLock(String identifier) async {
    _failedAttempts.remove(identifier);
    _locks.remove(identifier);
  }

  @override
  Future<LockInfo?> getLockInfo(String identifier) async {
    final lock = _locks[identifier];
    if (lock == null) {
      return null;
    }
    if (lock.until.isBefore(DateTime.now())) {
      _locks.remove(identifier);
      return null;
    }
    return lock;
  }

  @override
  Future<void> recordFailedAttempt({
    required String identifier,
    required SessionMetadata session,
    required String reason,
  }) async {
    final attempts = (_failedAttempts[identifier] ?? 0) + 1;
    _failedAttempts[identifier] = attempts;
    if (attempts >= 5) {
      final until = DateTime.now().add(const Duration(minutes: 15));
      _locks[identifier] = LockInfo(
        until: until,
        reason: reason,
        remainingAttempts: 0,
      );
    }
  }

  @override
  Future<void> recordSuccessfulLogin({
    required String identifier,
    required SessionMetadata session,
  }) async {
    await clearLock(identifier);
  }

  @override
  Future<List<MfaChannel>> fetchAvailableMfaChannels(String identifier) async {
    return _userMfaChannels[identifier] ?? const [];
  }

  @override
  Future<void> sendOtp({
    required String identifier,
    required MfaChannel channel,
  }) async {
    if (channel != MfaChannel.smsOtp && channel != MfaChannel.emailOtp) {
      throw LoginException('Bu MFA kanalı OTP gönderimini desteklemiyor.', code: 'invalid_channel');
    }
  }

  @override
  Future<String> sendMagicLink({
    required String identifier,
  }) async {
    if (identifier == 'locked@cringe.bank') {
      throw LoginException('Çok fazla deneme yapıldı.', code: 'too_many_attempts');
    }
    return 'mock-magic-token';
  }

  @override
  Future<void> verifyMagicLink({
    required String token,
    required String identifier,
  }) async {
    if (token != 'mock-magic-token') {
      throw LoginException('Sihirli bağlantı doğrulanamadı.', code: 'invalid_magic_link');
    }
  }

  @override
  Future<String> requestPasswordReset({
    required String identifier,
  }) async {
    if (identifier.isEmpty) {
      throw LoginException('Kimlik bilgisi gerekli.', code: 'invalid_identifier');
    }
    if (identifier == 'locked@cringe.bank') {
      throw LoginException('Çok fazla deneme yapıldı.', code: 'too_many_attempts');
    }
    final token = 'reset-token-${DateTime.now().millisecondsSinceEpoch}';
    _passwordResetTokens[token] = identifier;
    return token;
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final identifier = _passwordResetTokens[token];
    if (identifier == null) {
      throw LoginException('Geçersiz veya süresi dolmuş bağlantı.', code: 'invalid_reset_token');
    }
    if (newPassword.length < 8) {
      throw LoginException('Parola yeterince güçlü değil.', code: 'weak_password');
    }
    _passwordResetTokens.remove(token);
  }

  @override
  Future<void> verifyOtp({
    required String identifier,
    required String code,
    required MfaChannel channel,
  }) async {
    if (code != '123456') {
      throw LoginException('OTP kodu hatalı.', code: 'invalid_otp');
    }
  }

  @override
  Future<void> verifyTotp({
    required String identifier,
    required String code,
  }) async {
    if (code != '654321') {
      throw LoginException('TOTP kodu hatalı.', code: 'invalid_totp');
    }
  }

  @override
  Future<PasskeyChallenge> createPasskeyChallenge({
    required String identifier,
    required DeviceInfo deviceInfo,
  }) async {
    return PasskeyChallenge(
      challengeId: 'challenge-${DateTime.now().millisecondsSinceEpoch}',
      rpId: 'cringebank.dev',
      userId: identifier,
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Future<void> verifyPasskeyAssertion({
    required String identifier,
    required String challengeId,
    required String clientDataJson,
    required String authenticatorData,
    required String signature,
  }) async {
    if (signature.isEmpty) {
      throw LoginException('Geçersiz passkey yanıtı.', code: 'invalid_passkey');
    }
  }

  // Helpers for tests/demo
  void setMfaChannels(String identifier, List<MfaChannel> channels) {
    _userMfaChannels[identifier] = channels;
  }

  void setRequiresVerification(String identifier, bool requiresVerification) {
    if (requiresVerification) {
      _requiresVerification.add(identifier);
    } else {
      _requiresVerification.remove(identifier);
    }
  }

  void setRoles(String identifier, Set<LoginAccountRole> roles) {
    _roles[identifier] = Set<LoginAccountRole>.unmodifiable(roles);
  }

  void reset() {
    _failedAttempts.clear();
    _locks.clear();
    _userMfaChannels.clear();
    _requiresVerification.clear();
    _passwordResetTokens.clear();
    _roles.clear();
    authenticateCalls = 0;
  }
}
