import 'package:equatable/equatable.dart';

enum LoginStep {
  credentials,
  mfaSelection,
  otp,
  totp,
  passkey,
  magicLink,
  passwordResetRequest,
  passwordResetConfirm,
  passwordResetComplete,
  success,
  locked,
}

enum LoginMethod {
  emailPassword,
  phoneOtp,
  magicLink,
}

enum LoginAccountRole {
  user,
  moderator,
  admin,
  superAdmin,
}

enum MfaChannel {
  totp,
  smsOtp,
  emailOtp,
  passkey,
}

class CredentialsForm extends Equatable {
  const CredentialsForm({
    this.identifier = '',
    this.password = '',
    this.rememberMe = false,
    this.captchaToken,
  });

  final String identifier;
  final String password;
  final bool rememberMe;
  final String? captchaToken;

  CredentialsForm copyWith({
    String? identifier,
    String? password,
    bool? rememberMe,
    Object? captchaToken = _copySentinel,
  }) {
    return CredentialsForm(
      identifier: identifier ?? this.identifier,
      password: password ?? this.password,
      rememberMe: rememberMe ?? this.rememberMe,
      captchaToken: identical(captchaToken, _copySentinel)
          ? this.captchaToken
          : captchaToken as String?,
    );
  }

  static const _copySentinel = Object();

  bool get isComplete => identifier.trim().isNotEmpty && password.isNotEmpty;

  @override
  List<Object?> get props => [identifier, password, rememberMe, captchaToken];
}

class OtpForm extends Equatable {
  const OtpForm({
    this.code = '',
    this.attemptsRemaining = 5,
    this.resendAvailableAt,
    this.channel,
  });

  final String code;
  final int attemptsRemaining;
  final DateTime? resendAvailableAt;
  final MfaChannel? channel;

  OtpForm copyWith({
    String? code,
    int? attemptsRemaining,
    DateTime? resendAvailableAt,
    MfaChannel? channel,
  }) {
    return OtpForm(
      code: code ?? this.code,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
      resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
      channel: channel ?? this.channel,
    );
  }

  bool get canSubmit => code.length == 6 && attemptsRemaining > 0;

  bool canResend(DateTime now) {
    if (resendAvailableAt == null) {
      return true;
    }
    return now.isAfter(resendAvailableAt!);
  }

  @override
  List<Object?> get props => [code, attemptsRemaining, resendAvailableAt, channel];
}

class TotpForm extends Equatable {
  const TotpForm({
    this.code = '',
    this.deviceName,
    this.attemptsRemaining = 5,
  });

  final String code;
  final String? deviceName;
  final int attemptsRemaining;

  TotpForm copyWith({
    String? code,
    String? deviceName,
    int? attemptsRemaining,
  }) {
    return TotpForm(
      code: code ?? this.code,
      deviceName: deviceName ?? this.deviceName,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
    );
  }

  bool get canSubmit => code.length >= 6 && attemptsRemaining > 0;

  @override
  List<Object?> get props => [code, deviceName, attemptsRemaining];
}

class PasskeyState extends Equatable {
  const PasskeyState({
    this.challengeId,
    this.isInProgress = false,
    this.errorMessage,
  });

  final String? challengeId;
  final bool isInProgress;
  final String? errorMessage;

  PasskeyState copyWith({
    String? challengeId,
    bool? isInProgress,
    Object? errorMessage = _copySentinel,
  }) {
    return PasskeyState(
      challengeId: challengeId ?? this.challengeId,
      isInProgress: isInProgress ?? this.isInProgress,
      errorMessage: identical(errorMessage, _copySentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const _copySentinel = Object();

  @override
  List<Object?> get props => [challengeId, isInProgress, errorMessage];
}

class MagicLinkState extends Equatable {
  const MagicLinkState({
    this.token,
    this.sentAt,
    this.resendAvailableAt,
    this.isVerifying = false,
    this.errorMessage,
  });

  final String? token;
  final DateTime? sentAt;
  final DateTime? resendAvailableAt;
  final bool isVerifying;
  final String? errorMessage;

  MagicLinkState copyWith({
    String? token,
    DateTime? sentAt,
    DateTime? resendAvailableAt,
    bool? isVerifying,
    Object? errorMessage = _copySentinel,
  }) {
    return MagicLinkState(
      token: token ?? this.token,
      sentAt: sentAt ?? this.sentAt,
      resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
      isVerifying: isVerifying ?? this.isVerifying,
      errorMessage: identical(errorMessage, _copySentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  bool canResend(DateTime now) {
    if (resendAvailableAt == null) {
      return true;
    }
    return now.isAfter(resendAvailableAt!);
  }

  static const _copySentinel = Object();

  @override
  List<Object?> get props => [token, sentAt, resendAvailableAt, isVerifying, errorMessage];
}

class PasswordResetState extends Equatable {
  const PasswordResetState({
    this.identifier = '',
    this.token,
    this.newPassword = '',
    this.confirmPassword = '',
    this.errorMessage,
    this.hasSentLink = false,
  });

  final String identifier;
  final String? token;
  final String newPassword;
  final String confirmPassword;
  final String? errorMessage;
  final bool hasSentLink;

  PasswordResetState copyWith({
    String? identifier,
    Object? token = _copySentinel,
    String? newPassword,
    String? confirmPassword,
    Object? errorMessage = _copySentinel,
    bool? hasSentLink,
  }) {
    return PasswordResetState(
      identifier: identifier ?? this.identifier,
      token: identical(token, _copySentinel) ? this.token : token as String?,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      errorMessage: identical(errorMessage, _copySentinel)
          ? this.errorMessage
          : errorMessage as String?,
      hasSentLink: hasSentLink ?? this.hasSentLink,
    );
  }

  static const _copySentinel = Object();

  bool get canSubmitIdentifier => identifier.trim().isNotEmpty;

  bool get canSubmitNewPassword =>
      token != null && newPassword.length >= 8 && newPassword == confirmPassword;

  @override
  List<Object?> get props => [identifier, token, newPassword, confirmPassword, errorMessage, hasSentLink];
}

class LockInfo extends Equatable {
  const LockInfo({
    required this.until,
    required this.reason,
    required this.remainingAttempts,
  });

  final DateTime until;
  final String reason;
  final int remainingAttempts;

  @override
  List<Object?> get props => [until, reason, remainingAttempts];
}

class DeviceInfo extends Equatable {
  const DeviceInfo({
    required this.deviceIdHash,
    required this.isTrusted,
  });

  final String deviceIdHash;
  final bool isTrusted;

  @override
  List<Object?> get props => [deviceIdHash, isTrusted];
}

class SessionMetadata extends Equatable {
  const SessionMetadata({
    required this.ipHash,
    required this.userAgent,
    required this.locale,
    required this.timeZone,
  });

  final String ipHash;
  final String userAgent;
  final String locale;
  final String timeZone;

  @override
  List<Object?> get props => [ipHash, userAgent, locale, timeZone];
}

class LoginState extends Equatable {
  LoginState({
    required this.step,
    required this.method,
    required this.credentials,
    required this.otp,
    required this.totp,
    required this.passkey,
    required this.magicLink,
    required this.passwordReset,
    required this.availableMfaChannels,
    required this.isLoading,
    required this.errorMessage,
    required this.lockInfo,
    required this.requiresVerification,
    required this.failedAttempts,
    required this.captchaRequired,
    required this.requiresDeviceVerification,
    required Set<LoginAccountRole> roles,
    required this.rememberMeForcedOff,
  }) : roles = Set<LoginAccountRole>.unmodifiable(roles);

  final LoginStep step;
  final LoginMethod method;
  final CredentialsForm credentials;
  final OtpForm otp;
  final TotpForm totp;
  final PasskeyState passkey;
  final MagicLinkState magicLink;
  final PasswordResetState passwordReset;
  final List<MfaChannel> availableMfaChannels;
  final bool isLoading;
  final String? errorMessage;
  final LockInfo? lockInfo;
  final bool requiresVerification;
  final int failedAttempts;
  final bool captchaRequired;
  final bool requiresDeviceVerification;
  final Set<LoginAccountRole> roles;
  final bool rememberMeForcedOff;

  factory LoginState.initial() {
    return LoginState(
      step: LoginStep.credentials,
      method: LoginMethod.emailPassword,
      credentials: const CredentialsForm(),
      otp: const OtpForm(),
      totp: const TotpForm(),
      passkey: const PasskeyState(),
  magicLink: const MagicLinkState(),
  passwordReset: const PasswordResetState(),
      availableMfaChannels: const [],
      isLoading: false,
      errorMessage: null,
      lockInfo: null,
      requiresVerification: false,
      failedAttempts: 0,
      captchaRequired: false,
      requiresDeviceVerification: false,
      rememberMeForcedOff: false,
      roles: const {LoginAccountRole.user},
    );
  }

  LoginState copyWith({
    LoginStep? step,
    LoginMethod? method,
    CredentialsForm? credentials,
    OtpForm? otp,
    TotpForm? totp,
    PasskeyState? passkey,
  MagicLinkState? magicLink,
  PasswordResetState? passwordReset,
    List<MfaChannel>? availableMfaChannels,
    bool? isLoading,
    Object? errorMessage = _copySentinel,
    Object? lockInfo = _copySentinel,
    bool? requiresVerification,
    int? failedAttempts,
    bool? captchaRequired,
    bool? requiresDeviceVerification,
    Set<LoginAccountRole>? roles,
    bool? rememberMeForcedOff,
  }) {
    return LoginState(
      step: step ?? this.step,
      method: method ?? this.method,
      credentials: credentials ?? this.credentials,
      otp: otp ?? this.otp,
      totp: totp ?? this.totp,
      passkey: passkey ?? this.passkey,
  magicLink: magicLink ?? this.magicLink,
  passwordReset: passwordReset ?? this.passwordReset,
      availableMfaChannels: availableMfaChannels ?? this.availableMfaChannels,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _copySentinel)
      ? this.errorMessage
      : errorMessage as String?,
      lockInfo: identical(lockInfo, _copySentinel)
      ? this.lockInfo
      : lockInfo as LockInfo?,
      requiresVerification: requiresVerification ?? this.requiresVerification,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      captchaRequired: captchaRequired ?? this.captchaRequired,
      requiresDeviceVerification:
          requiresDeviceVerification ?? this.requiresDeviceVerification,
      rememberMeForcedOff: rememberMeForcedOff ?? this.rememberMeForcedOff,
      roles: roles != null
          ? Set<LoginAccountRole>.unmodifiable(roles)
          : this.roles,
    );
  }

  static const _copySentinel = Object();

  bool get isLocked => step == LoginStep.locked || lockInfo != null;

  bool get canAttemptLogin =>
      step == LoginStep.credentials && !isLoading && !isLocked;

  @override
  List<Object?> get props => [
        step,
        method,
        credentials,
        otp,
        totp,
        passkey,
        magicLink,
  passwordReset,
        availableMfaChannels,
        isLoading,
        errorMessage,
        lockInfo,
    requiresVerification,
    failedAttempts,
    captchaRequired,
    requiresDeviceVerification,
        rememberMeForcedOff,
        List<LoginAccountRole>.unmodifiable(
          roles.toList()..sort((a, b) => a.index.compareTo(b.index)),
        ),
      ];
}
