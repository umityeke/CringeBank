import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/session/device_fingerprint_controller.dart';
import '../../../core/session/session_bootstrap.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_refresh_service.dart';
import '../../../core/session/session_remote_repository.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/telemetry/telemetry_utils.dart';
import '../../../core/config/super_admin_security_policy.dart';
import '../data/login_local_storage.dart';
import '../domain/models/login_models.dart';
import '../domain/services/login_service.dart';
import '../data/login_audit_service.dart';

class LoginController extends StateNotifier<LoginState> {
  LoginController(
    this._service, {
    DateTime Function()? now,
    DeviceInfo? deviceInfo,
    SessionMetadata Function()? sessionBuilder,
    SessionController? sessionController,
    LoginLocalStorage? loginStorage,
    TelemetryService? telemetry,
    FeatureFlags? featureFlags,
    SuperAdminSecurityPolicy? superAdminPolicy,
    SessionRefreshCoordinator? sessionRefreshCoordinator,
    DeviceFingerprintController? deviceFingerprintController,
  LoginAuditService? loginAuditService,
  })  : _now = now ?? DateTime.now,
        _deviceInfo =
            deviceInfo ?? const DeviceInfo(deviceIdHash: 'mock-device', isTrusted: false),
        _deviceFingerprintController = deviceFingerprintController,
        _sessionBuilder = sessionBuilder ??
            (() => const SessionMetadata(
                  ipHash: '0.0.0.0',
                  userAgent: 'Unknown',
                  locale: 'tr-TR',
                  timeZone: 'UTC+03:00',
                )),
        _sessionController = sessionController,
        _loginStorage = loginStorage,
        _telemetry = telemetry,
        _featureFlags = featureFlags ?? const FeatureFlags(),
        _superAdminPolicy = superAdminPolicy ?? SuperAdminSecurityPolicy(),
        _sessionRefreshCoordinator = sessionRefreshCoordinator,
        _loginAuditService = loginAuditService,
        super(LoginState.initial()) {
    if (!_isMethodEnabled(state.method)) {
      state = state.copyWith(method: _firstEnabledMethod());
    }
  }

  static const _rememberMeRetention = Duration(days: 30);
  static const _defaultSessionTtl = Duration(hours: 12);
  static const _rememberMeSessionTtl = Duration(days: 30);
  final LoginService _service;
  final DateTime Function() _now;
  DeviceInfo _deviceInfo;
  final SessionMetadata Function() _sessionBuilder;
  final SessionController? _sessionController;
  final LoginLocalStorage? _loginStorage;
  final TelemetryService? _telemetry;
  final FeatureFlags _featureFlags;
  final SuperAdminSecurityPolicy _superAdminPolicy;
  final SessionRefreshCoordinator? _sessionRefreshCoordinator;
  final DeviceFingerprintController? _deviceFingerprintController;
  final LoginAuditService? _loginAuditService;
  int _credentialFailures = 0;
  Set<LoginAccountRole> _currentRoles = const {LoginAccountRole.user};

  bool _isMethodEnabled(LoginMethod method) {
    switch (method) {
      case LoginMethod.emailPassword:
        return true;
      case LoginMethod.phoneOtp:
        return _featureFlags.loginWithPhone;
      case LoginMethod.magicLink:
        return _featureFlags.magicLinkLogin;
    }
  }

  LoginMethod _firstEnabledMethod() {
    return LoginMethod.values.firstWhere(
      _isMethodEnabled,
      orElse: () => LoginMethod.emailPassword,
    );
  }

  List<MfaChannel> _deriveMfaChannels(
    List<MfaChannel> channels,
    Set<LoginAccountRole> roles,
  ) {
    final allowPasskey = _featureFlags.webauthnPasskey;
    final sanitized = <MfaChannel>[];
    for (final channel in channels) {
      if (!allowPasskey && channel == MfaChannel.passkey) {
        continue;
      }
      if (roles.contains(LoginAccountRole.superAdmin) &&
          (channel == MfaChannel.smsOtp || channel == MfaChannel.emailOtp)) {
        continue;
      }
      sanitized.add(channel);
    }
    return sanitized;
  }

  bool _requiresMfaForRoles(Set<LoginAccountRole> roles) {
    if (roles.contains(LoginAccountRole.superAdmin)) {
      return true;
    }
    if (!_featureFlags.requireMfaForAdmins) {
      return false;
    }
    return roles.contains(LoginAccountRole.admin) || roles.contains(LoginAccountRole.moderator);
  }

  Future<void> hydrate() async {
    final storage = _loginStorage;
    if (storage == null) {
      return;
    }
    final persisted = await storage.load();
    if (!mounted || persisted == null) {
      return;
    }
    final isExpired = _now().difference(persisted.timestamp) > _rememberMeRetention;
    if (isExpired) {
      await storage.clear();
      return;
    }
    state = state.copyWith(
      credentials: state.credentials.copyWith(
        identifier: persisted.identifier,
        rememberMe: persisted.rememberMe,
      ),
    );
  }

  void changeMethod(LoginMethod method) {
    if (state.isLoading || state.method == method) return;
    if (!_isMethodEnabled(method)) {
      state = state.copyWith(
        errorMessage: 'Bu giriş yöntemi şu anda devre dışı. Lütfen farklı bir yöntem dene.',
      );
      return;
    }
    state = state.copyWith(
      method: method,
      errorMessage: null,
      step: LoginStep.credentials,
      otp: const OtpForm(),
      totp: const TotpForm(),
      passkey: const PasskeyState(),
      magicLink: const MagicLinkState(),
      passwordReset: const PasswordResetState(),
      isLoading: false,
    );
  }

  void updateIdentifier(String value) {
    state = state.copyWith(
      credentials: state.credentials.copyWith(identifier: value),
      errorMessage: null,
    );
  }

  void updatePassword(String value) {
    state = state.copyWith(
      credentials: state.credentials.copyWith(password: value),
      errorMessage: null,
    );
  }

  void toggleRememberMe(bool value) {
    state = state.copyWith(
      credentials: state.credentials.copyWith(rememberMe: value),
    );
    if (!value) {
      final storage = _loginStorage;
      if (storage != null) {
        unawaited(storage.clear());
      }
    }
  }

  void startPasswordReset() {
    if (state.isLoading) return;
    state = state.copyWith(
      step: LoginStep.passwordResetRequest,
      errorMessage: null,
      passwordReset: state.passwordReset.copyWith(
        identifier: state.credentials.identifier,
        errorMessage: null,
        hasSentLink: false,
        token: null,
        newPassword: '',
        confirmPassword: '',
      ),
    );
  }

  void cancelPasswordReset() {
    if (state.isLoading) return;
    state = state.copyWith(
      step: LoginStep.credentials,
      passwordReset: const PasswordResetState(),
      errorMessage: null,
    );
  }

  void updatePasswordResetIdentifier(String value) {
    state = state.copyWith(
      passwordReset: state.passwordReset.copyWith(identifier: value, errorMessage: null),
    );
  }

  void updatePasswordResetNewPassword(String value) {
    state = state.copyWith(
      passwordReset: state.passwordReset.copyWith(newPassword: value, errorMessage: null),
    );
  }

  void updatePasswordResetConfirmPassword(String value) {
    state = state.copyWith(
      passwordReset: state.passwordReset.copyWith(confirmPassword: value, errorMessage: null),
    );
  }

  void setCaptchaToken(String? token) {
    state = state.copyWith(
      credentials: state.credentials.copyWith(captchaToken: token),
    );
  }

  void setDeviceInfo({
    required String deviceIdHash,
    required bool isTrusted,
  }) {
    _deviceInfo = DeviceInfo(
      deviceIdHash: deviceIdHash,
      isTrusted: isTrusted,
    );
  }

  String get deviceIdHash => _deviceInfo.deviceIdHash;

  Future<void> loadLockInfo() async {
    final lock = await _service.getLockInfo(state.credentials.identifier.trim());
    if (!mounted) return;
    state = state.copyWith(lockInfo: lock, step: lock != null ? LoginStep.locked : state.step);
  }

  Future<void> submitCredentials() async {
    if (!state.canAttemptLogin) return;
    final identifier = state.credentials.identifier.trim();

    if (identifier.isEmpty) {
      state = state.copyWith(errorMessage: 'Kimlik bilgisini girmen gerekiyor.');
      _emitLoginAttempt(identifier: identifier, success: false, reason: 'missing_identifier');
      _emitLoginFailure(
        identifier: identifier,
        reason: 'missing_identifier',
        stage: 'credentials',
        attributes: {
          'failedAttempts': state.failedAttempts,
          'captchaRequired': state.captchaRequired,
        },
      );
      return;
    }

    if (state.captchaRequired &&
        (state.credentials.captchaToken == null || state.credentials.captchaToken!.isEmpty)) {
      state = state.copyWith(errorMessage: 'Güvenlik doğrulamasını tamamlamalısın.');
      _emitLoginAttempt(
        identifier: identifier,
        success: false,
        reason: 'captcha_required_unfulfilled',
      );
      _emitLoginFailure(
        identifier: identifier,
        reason: 'captcha_required_unfulfilled',
        stage: 'credentials',
        attributes: {
          'failedAttempts': state.failedAttempts,
          'captchaRequired': state.captchaRequired,
        },
      );
      return;
    }

    if (!_isMethodEnabled(state.method)) {
      final fallback = _firstEnabledMethod();
      state = state.copyWith(
        method: fallback,
        errorMessage: 'Bu giriş yöntemi şu anda devre dışı. Lütfen farklı bir yöntem dene.',
      );
      return;
    }

    if (state.method == LoginMethod.phoneOtp) {
      final sessionMetadata = _telemetry != null ? _sessionBuilder() : null;
      _emitLoginAttempt(
        identifier: identifier,
        success: null,
        reason: null,
        session: sessionMetadata,
      );
      await _startPhoneOtpFlow(identifier: identifier);
      return;
    }

    if (state.method == LoginMethod.magicLink) {
      final sessionMetadata = _telemetry != null ? _sessionBuilder() : null;
      _emitLoginAttempt(
        identifier: identifier,
        success: null,
        reason: null,
        session: sessionMetadata,
      );
      await _startMagicLinkFlow(identifier: identifier);
      return;
    }

    if (state.credentials.password.isEmpty) {
      state = state.copyWith(errorMessage: 'Parolanı girmelisin.');
      _emitLoginAttempt(identifier: identifier, success: false, reason: 'missing_password');
      _emitLoginFailure(
        identifier: identifier,
        reason: 'missing_password',
        stage: 'credentials',
        attributes: {
          'failedAttempts': state.failedAttempts,
          'captchaRequired': state.captchaRequired,
        },
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    final sessionMetadata = _sessionBuilder();
    _emitLoginAttempt(
      identifier: identifier,
      success: null,
      reason: null,
      session: sessionMetadata,
    );

    try {
      final result = await _service.authenticate(
        method: state.method,
        identifier: identifier,
        password: state.credentials.password,
        credentials: state.credentials,
        deviceInfo: _deviceInfo,
        session: sessionMetadata,
      );

      if (!mounted) return;

      final roles = result.roles;
      _currentRoles = roles;
      state = state.copyWith(roles: roles);

      if (result.requiresVerification) {
        _credentialFailures = 0;
        final clearedCredentials = state.credentials.copyWith(captchaToken: null);
        state = state.copyWith(
          isLoading: false,
          requiresVerification: true,
          errorMessage: 'Hesabını doğrulaman gerekiyor. Lütfen e-postanı kontrol et.',
          failedAttempts: 0,
          captchaRequired: false,
          credentials: clearedCredentials,
        );
        _emitLoginAttempt(
          identifier: identifier,
          success: false,
          reason: 'requires_verification',
          session: sessionMetadata,
        );
        _emitLoginFailure(
          identifier: identifier,
          reason: 'requires_verification',
          stage: 'credentials',
          session: sessionMetadata,
          attributes: {
            'requiresVerification': true,
          },
        );
        return;
      }
  final availableChannels = _deriveMfaChannels(result.availableChannels, roles);
      final requiresMfa = result.requiresMfa || _requiresMfaForRoles(roles);

      if (roles.contains(LoginAccountRole.superAdmin)) {
        if (!_superAdminPolicy.isIpAllowed(sessionMetadata.ipHash)) {
          await _handleLoginFailure(
            identifier: identifier,
            message: 'Super admin girişleri yalnızca yetkili ağlardan yapılabilir.',
            reason: 'super_admin_ip_not_allowed',
          );
          return;
        }

        if (_superAdminPolicy.hasTimeZoneRestrictions &&
            !_superAdminPolicy.isTimeZoneAllowed(sessionMetadata.timeZone)) {
          await _handleLoginFailure(
            identifier: identifier,
            message: 'Bu hesap için sadece izin verilen zaman dilimlerinden giriş yapılabilir.',
            reason: 'super_admin_timezone_not_allowed',
          );
          return;
        }

        if (_superAdminPolicy.hasLocaleRestrictions &&
            !_superAdminPolicy.isLocaleAllowed(sessionMetadata.locale)) {
          await _handleLoginFailure(
            identifier: identifier,
            message: 'Bu hesap için yalnızca izin verilen bölge/locale ayarlarından giriş yapılabilir.',
            reason: 'super_admin_locale_not_allowed',
          );
          return;
        }

        if (_superAdminPolicy.requireTrustedDevice && !_deviceInfo.isTrusted) {
          await _handleLoginFailure(
            identifier: identifier,
            message:
                'Bu hesap için kayıtlı cihazla giriş yapılması gerekiyor. Lütfen doğrulanmış bir cihaz kullan.',
            reason: 'super_admin_untrusted_device',
          );
          return;
        }
      }

      if (roles.contains(LoginAccountRole.superAdmin)) {
        if (!_featureFlags.webauthnPasskey) {
          _credentialFailures = 0;
          final clearedCredentials = state.credentials.copyWith(captchaToken: null);
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'Super admin hesapları için passkey desteği zorunlu. Lütfen sistem yöneticinle iletişime geç.',
            credentials: clearedCredentials,
            captchaRequired: false,
            failedAttempts: 0,
          );
          _emitLoginAttempt(
            identifier: identifier,
            success: false,
            reason: 'super_admin_passkey_disabled',
            session: sessionMetadata,
          );
          _emitLoginFailure(
            identifier: identifier,
            reason: 'super_admin_passkey_disabled',
            stage: 'credentials',
            session: sessionMetadata,
            attributes: {
              'roles': roles.map((role) => role.name).toList(),
            },
          );
          return;
        }
        if (!result.availableChannels.contains(MfaChannel.passkey) ||
            !availableChannels.contains(MfaChannel.passkey)) {
          _credentialFailures = 0;
          final clearedCredentials = state.credentials.copyWith(captchaToken: null);
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'Bu super admin hesabı için passkey kaydı bulunamadı. Lütfen güvenlik ekibiyle iletişime geç.',
            credentials: clearedCredentials,
            captchaRequired: false,
            failedAttempts: 0,
          );
          _emitLoginAttempt(
            identifier: identifier,
            success: false,
            reason: 'super_admin_missing_passkey',
            session: sessionMetadata,
          );
          _emitLoginFailure(
            identifier: identifier,
            reason: 'super_admin_missing_passkey',
            stage: 'credentials',
            session: sessionMetadata,
            attributes: {
              'initialChannels': result.availableChannels.map((channel) => channel.name).toList(),
              'normalizedChannels': availableChannels.map((channel) => channel.name).toList(),
              'roles': roles.map((role) => role.name).toList(),
            },
          );
          return;
        }
      }

  if (requiresMfa && availableChannels.isEmpty) {
        _credentialFailures = 0;
        final clearedCredentials = state.credentials.copyWith(captchaToken: null);
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Bu hesap için zorunlu doğrulama devrede ancak uygun bir yöntem tanımlı değil. Lütfen destek ekibiyle iletişime geç.',
          credentials: clearedCredentials,
          captchaRequired: false,
          failedAttempts: 0,
        );
        _emitLoginAttempt(
          identifier: identifier,
          success: false,
          reason: 'mfa_channel_unavailable',
          session: sessionMetadata,
        );
        _emitLoginFailure(
          identifier: identifier,
          reason: 'mfa_channel_unavailable',
          stage: 'credentials',
          session: sessionMetadata,
          attributes: {
            'initialChannels': result.availableChannels.map((channel) => channel.name).toList(),
            'normalizedChannels': availableChannels.map((channel) => channel.name).toList(),
            'roles': roles.map((role) => role.name).toList(),
          },
        );
        return;
      }

  if (requiresMfa) {
        _credentialFailures = 0;
        final channels = availableChannels;
        final nextStep = channels.length > 1 ? LoginStep.mfaSelection : _resolveMfaStep(channels);
        final clearedCredentials = state.credentials.copyWith(captchaToken: null);
        state = state.copyWith(
          isLoading: false,
          step: nextStep,
          availableMfaChannels: channels,
          failedAttempts: 0,
          captchaRequired: false,
          credentials: clearedCredentials,
          otp: state.otp.copyWith(
            channel: () {
              if (channels.length != 1) {
                return null;
              }
              final onlyChannel = channels.first;
              if (onlyChannel == MfaChannel.smsOtp || onlyChannel == MfaChannel.emailOtp) {
                return onlyChannel;
              }
              return null;
            }(),
          ),
          errorMessage: null,
        );
        _emitMfaChallenge(
          identifier: identifier,
          channels: channels,
          session: sessionMetadata,
          source: 'post_credentials',
        );

        if (channels.length == 1) {
          switch (channels.first) {
            case MfaChannel.smsOtp:
            case MfaChannel.emailOtp:
              await _startOtpFlow(identifier: identifier, channel: channels.first, fromMfa: true);
              break;
            case MfaChannel.totp:
            case MfaChannel.passkey:
              // No immediate action; corresponding step handles user input.
              break;
          }
        }
        return;
      }

  state = state.copyWith(availableMfaChannels: availableChannels);
  await _completeLoginSuccess(identifier);
      return;
    } on LoginException catch (error) {
      await _handleLoginFailure(
        identifier: identifier,
        message: error.message,
        reason: error.code,
      );
    } catch (_) {
      await _handleLoginFailure(
        identifier: identifier,
        message: 'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.',
        reason: 'unexpected_error',
      );
    }
  }

  Future<void> _startPhoneOtpFlow({required String identifier}) async {
    if (!_featureFlags.loginWithPhone) {
      state = state.copyWith(errorMessage: 'Telefonla giriş şu anda devre dışı.');
      return;
    }
    await _startOtpFlow(identifier: identifier, channel: MfaChannel.smsOtp, fromPhone: true);
  }

  Future<void> _startOtpFlow({
    required String identifier,
    required MfaChannel channel,
    bool fromPhone = false,
    bool fromMfa = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    _emitMfaChallenge(
      identifier: identifier,
      channels: [channel],
      session: null,
      source: fromPhone
          ? 'phone_otp'
          : fromMfa
              ? 'mfa_selection'
              : 'direct',
    );
    try {
      await _service.sendOtp(identifier: identifier, channel: channel);
      if (!mounted) return;
      final channels = fromPhone
          ? const [MfaChannel.smsOtp]
          : (fromMfa ? state.availableMfaChannels : state.availableMfaChannels.isEmpty
              ? [channel]
              : state.availableMfaChannels);
      state = state.copyWith(
        isLoading: false,
        step: LoginStep.otp,
        availableMfaChannels: channels,
        otp: state.otp.copyWith(
          channel: channel,
          code: '',
          attemptsRemaining: 5,
          resendAvailableAt: _now().add(const Duration(seconds: 60)),
        ),
      );
    } on LoginException catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Kod gönderimi sırasında hata oluştu. Lütfen tekrar dene.',
      );
    }
  }

  Future<void> _completeLoginSuccess(String identifier) async {
    final sessionMetadata = _sessionBuilder();
    await _service.recordSuccessfulLogin(
      identifier: identifier,
      session: sessionMetadata,
    );
    _credentialFailures = 0;
    final issuedAt = _now();
    final isSuperAdmin = _currentRoles.contains(LoginAccountRole.superAdmin);
    final rememberMeSelection = state.credentials.rememberMe;
    final superAdminPolicy = _superAdminPolicy;
    final rememberMeForcedOff = isSuperAdmin && superAdminPolicy.forceRememberMeDisabled;
    final rememberMe = rememberMeForcedOff ? false : rememberMeSelection;
    final sessionTtl = isSuperAdmin
        ? superAdminPolicy.sessionTtl
        : (rememberMe ? _rememberMeSessionTtl : _defaultSessionTtl);
    final sessionController = _sessionController;
    bool requiresDeviceVerification = false;
    if (sessionController != null) {
      await sessionController.setAuthenticated(
        identifier: identifier,
        authenticatedAt: issuedAt,
        ttl: sessionTtl,
        loginContext: SessionLoginContext(
          deviceIdHash: _deviceInfo.deviceIdHash,
          ipHash: sessionMetadata.ipHash,
          userAgent: sessionMetadata.userAgent,
          locale: sessionMetadata.locale,
          timeZone: sessionMetadata.timeZone,
        ),
      );
      requiresDeviceVerification = sessionController.state.requiresDeviceVerification;
    }
    await _updateDeviceTrust(trusted: !requiresDeviceVerification);
    _sessionRefreshCoordinator?.registerSession(
      identifier: identifier,
      session: SessionBootstrapData(
        identifier: identifier,
        issuedAt: issuedAt,
        expiresAt: issuedAt.add(sessionTtl),
        rememberMe: rememberMe,
        requiresDeviceVerification: requiresDeviceVerification,
        metadata: {
          'roles': _currentRoles
              .map((role) => role.name)
              .toList(growable: false),
        },
      ),
    );
    final loginAuditService = _loginAuditService;
    if (loginAuditService != null) {
      unawaited(
        loginAuditService.recordSuccessfulLogin(
          identifier: identifier,
          session: sessionMetadata,
          deviceIdHash: _deviceInfo.deviceIdHash,
          isTrustedDevice: _deviceInfo.isTrusted,
          rememberMe: rememberMe,
          requiresDeviceVerification: requiresDeviceVerification,
        ),
      );
    }
    if (!mounted) return;
    final updatedCredentials = state.credentials.copyWith(
      password: '',
      captchaToken: null,
      rememberMe: rememberMe,
    );
    state = state.copyWith(
      isLoading: false,
      step: LoginStep.success,
      credentials: updatedCredentials,
      otp: const OtpForm(),
      totp: const TotpForm(),
      passkey: const PasskeyState(),
      magicLink: const MagicLinkState(),
      passwordReset: const PasswordResetState(),
      failedAttempts: 0,
      captchaRequired: false,
      requiresDeviceVerification:
          requiresDeviceVerification,
      rememberMeForcedOff: rememberMeForcedOff,
      roles: _currentRoles,
    );
    _emitLoginAttempt(
      identifier: identifier,
      success: true,
      reason: null,
      session: sessionMetadata,
    );
    _emitLoginSuccess(
      identifier: identifier,
      rememberMe: rememberMe,
      requiresDeviceVerification: requiresDeviceVerification,
      sessionTtl: sessionTtl,
      session: sessionMetadata,
    );
    await _persistRememberMe(
      identifier,
      issuedAt: issuedAt,
      rememberMe: rememberMe,
    );
  }

  Future<void> _persistRememberMe(
    String identifier, {
    required DateTime issuedAt,
    required bool rememberMe,
  }) async {
    final storage = _loginStorage;
    if (storage == null) {
      return;
    }
    if (!rememberMe) {
      await storage.clear();
      return;
    }
    await storage.save(
      identifier: identifier,
      rememberMe: true,
      timestamp: issuedAt,
    );
  }

  Future<void> _startMagicLinkFlow({required String identifier}) async {
    if (!_featureFlags.magicLinkLogin) {
      state = state.copyWith(errorMessage: 'Sihirli bağlantı ile giriş şu anda devre dışı.');
      return;
    }
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      magicLink: state.magicLink.copyWith(isVerifying: false, errorMessage: null),
    );
    try {
      final token = await _service.sendMagicLink(identifier: identifier);
      if (!mounted) return;
      final now = _now();
      state = state.copyWith(
        isLoading: false,
        step: LoginStep.magicLink,
        magicLink: state.magicLink.copyWith(
          token: token,
          sentAt: now,
          resendAvailableAt: now.add(const Duration(minutes: 1)),
          isVerifying: false,
          errorMessage: null,
        ),
      );
    } on LoginException catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        magicLink: state.magicLink.copyWith(
          isVerifying: false,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sihirli bağlantı gönderilirken hata oluştu.',
        magicLink: state.magicLink.copyWith(
          isVerifying: false,
          errorMessage: 'Sihirli bağlantı gönderilirken hata oluştu.',
        ),
      );
    }
  }

  LoginStep _resolveMfaStep(List<MfaChannel> channels) {
    if (channels.contains(MfaChannel.passkey)) {
      return LoginStep.passkey;
    }
    if (channels.contains(MfaChannel.totp)) {
      return LoginStep.totp;
    }
    return LoginStep.otp;
  }

  Future<void> _handleLoginFailure({
    required String identifier,
    String? message,
    String? reason,
  }) async {
    final failureReason = reason ?? message ?? 'unknown_error';
    final sessionMetadata = _sessionBuilder();
    await _service.recordFailedAttempt(
      identifier: identifier,
      session: sessionMetadata,
      reason: failureReason,
    );
    final lock = await _service.getLockInfo(identifier);
    _credentialFailures = (_credentialFailures + 1).clamp(0, 99);
  final requireCaptcha =
    _featureFlags.enforceCaptchaAfterThreeFails && _credentialFailures >= 3;
    if (!mounted) return;
    final clearedCredentials = state.credentials.copyWith(captchaToken: null);
    state = state.copyWith(
      isLoading: false,
      errorMessage: message ?? 'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.',
      lockInfo: lock,
      step: lock != null ? LoginStep.locked : LoginStep.credentials,
      failedAttempts: _credentialFailures,
      captchaRequired: requireCaptcha,
      credentials: clearedCredentials,
    );
    _emitLoginAttempt(
      identifier: identifier,
      success: false,
      reason: failureReason,
      session: sessionMetadata,
    );
    _emitLoginFailure(
      identifier: identifier,
      reason: failureReason,
      stage: 'credentials',
      session: sessionMetadata,
      attributes: {
        'failedAttempts': _credentialFailures,
        'captchaRequired': requireCaptcha,
        'lockRemainingAttempts': lock?.remainingAttempts,
        'lockUntil': lock?.until.toIso8601String(),
      },
    );
    if (requireCaptcha) {
      _emitCaptchaRequired(
        identifier: identifier,
        failedAttempts: _credentialFailures,
        session: sessionMetadata,
      );
    }
    if (lock != null) {
      _emitAccountLock(
        identifier: identifier,
        lock: lock,
        stage: 'credentials',
        session: sessionMetadata,
      );
    }
  }

  Future<void> resendOtp() async {
    if (state.step != LoginStep.otp || state.isLoading) return;
    final channel = state.otp.channel;
    if (channel == null) return;
    if (!state.otp.canResend(_now())) {
      state = state.copyWith(errorMessage: 'OTP yeniden gönderimi için beklemen gerekiyor.');
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _service.sendOtp(
        identifier: state.credentials.identifier.trim(),
        channel: channel,
      );
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        otp: state.otp.copyWith(
          resendAvailableAt: _now().add(const Duration(seconds: 60)),
          attemptsRemaining: 5,
        ),
      );
    } on LoginException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'OTP gönderilirken hata oluştu.');
    }
  }

  Future<void> chooseMfaChannel(MfaChannel channel) async {
    if (state.isLoading) return;
    switch (channel) {
      case MfaChannel.smsOtp:
      case MfaChannel.emailOtp:
        await _startOtpFlow(
          identifier: state.credentials.identifier.trim(),
          channel: channel,
          fromMfa: true,
        );
        break;
      case MfaChannel.totp:
        state = state.copyWith(
          step: LoginStep.totp,
          errorMessage: null,
          totp: state.totp.copyWith(code: '', attemptsRemaining: 5),
        );
        break;
      case MfaChannel.passkey:
        if (!_featureFlags.webauthnPasskey) {
          state = state.copyWith(
            errorMessage: 'Passkey doğrulaması şu anda devre dışı.',
          );
          return;
        }
        state = state.copyWith(
          step: LoginStep.passkey,
          errorMessage: null,
          passkey: const PasskeyState(),
        );
        break;
    }
  }

  Future<void> resendMagicLink() async {
    if (state.step != LoginStep.magicLink || state.isLoading) return;
    if (!state.magicLink.canResend(_now())) {
      state = state.copyWith(
        magicLink: state.magicLink.copyWith(
          errorMessage: 'Bağlantıyı yeniden göndermek için biraz beklemelisin.',
        ),
      );
      return;
    }
    await _startMagicLinkFlow(identifier: state.credentials.identifier.trim());
  }

  void updateOtpCode(String value) {
    state = state.copyWith(
      otp: state.otp.copyWith(code: value.replaceAll(RegExp(r'[^0-9]'), '')),
      errorMessage: null,
    );
  }

  Future<void> verifyOtp() async {
    if (state.step != LoginStep.otp || state.isLoading || !state.otp.canSubmit) return;
    final identifier = state.credentials.identifier.trim();
    final channel = state.otp.channel ?? MfaChannel.smsOtp;
    state = state.copyWith(isLoading: true, errorMessage: null);
    _emitLoginAttempt(
      identifier: identifier,
      success: null,
      reason: null,
      stage: 'otp',
    );

    try {
      await _service.verifyOtp(
        identifier: identifier,
        code: state.otp.code,
        channel: channel,
      );
      _emitMfaSuccess(
        identifier: identifier,
        method: channel.name,
      );
  await _completeLoginSuccess(identifier);
      return;
    } on LoginException catch (error) {
      await _handleOtpFailure(
        identifier: identifier,
        message: error.message,
        reason: error.code ?? 'invalid_otp',
      );
    } catch (_) {
      await _handleOtpFailure(
        identifier: identifier,
        message: 'OTP doğrulanamadı.',
        reason: 'otp_verification_failed',
      );
    }
  }

  void updateTotpCode(String value) {
    state = state.copyWith(
      totp: state.totp.copyWith(code: value.trim()),
      errorMessage: null,
    );
  }

  Future<void> verifyTotp() async {
    if (state.step != LoginStep.totp || state.isLoading || !state.totp.canSubmit) return;
    final identifier = state.credentials.identifier.trim();
    state = state.copyWith(isLoading: true, errorMessage: null);
    _emitLoginAttempt(
      identifier: identifier,
      success: null,
      reason: null,
      stage: 'totp',
    );

    try {
      await _service.verifyTotp(identifier: identifier, code: state.totp.code);
      _emitMfaSuccess(
        identifier: identifier,
        method: 'totp',
      );
  await _completeLoginSuccess(identifier);
      return;
    } on LoginException catch (error) {
      await _handleTotpFailure(
        identifier: identifier,
        message: error.message,
        reason: error.code ?? 'invalid_totp',
      );
    } catch (_) {
      await _handleTotpFailure(
        identifier: identifier,
        message: 'Doğrulama kodu kabul edilmedi.',
        reason: 'totp_verification_failed',
      );
    }
  }

  Future<void> startPasskeyFlow() async {
    if (state.step != LoginStep.passkey || state.isLoading) return;
    if (!_featureFlags.webauthnPasskey) {
      state = state.copyWith(
        errorMessage: 'Passkey doğrulaması şu anda devre dışı.',
        step: LoginStep.mfaSelection,
      );
      return;
    }
    final identifier = state.credentials.identifier.trim();
    state = state.copyWith(
      isLoading: true,
      passkey: state.passkey.copyWith(isInProgress: true, errorMessage: null),
    );

    try {
      final challenge = await _service.createPasskeyChallenge(
        identifier: identifier,
        deviceInfo: _deviceInfo,
      );

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        passkey: state.passkey.copyWith(challengeId: challenge.challengeId, isInProgress: false),
      );
    } on LoginException catch (error) {
      state = state.copyWith(
        isLoading: false,
        passkey: state.passkey.copyWith(isInProgress: false, errorMessage: error.message),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        passkey: state.passkey.copyWith(
          isInProgress: false,
          errorMessage: 'Passkey doğrulaması başlatılamadı.',
        ),
      );
    }
  }

  Future<void> requestPasswordReset() async {
    if (state.isLoading) return;
    final identifier = state.passwordReset.identifier.trim();
    if (identifier.isEmpty) {
      state = state.copyWith(
        passwordReset: state.passwordReset.copyWith(errorMessage: 'E-posta adresini girmelisin.'),
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final token = await _service.requestPasswordReset(identifier: identifier);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        step: LoginStep.passwordResetConfirm,
        passwordReset: state.passwordReset.copyWith(
          token: token,
          hasSentLink: true,
          errorMessage: null,
          newPassword: '',
          confirmPassword: '',
        ),
      );
    } on LoginException catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        passwordReset: state.passwordReset.copyWith(errorMessage: error.message),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        passwordReset: state.passwordReset.copyWith(
          errorMessage: 'Parola sıfırlama bağlantısı gönderilemedi.',
        ),
      );
    }
  }

  Future<void> completePasswordReset() async {
    if (state.isLoading || !state.passwordReset.canSubmitNewPassword) {
      return;
    }
    final token = state.passwordReset.token;
    if (token == null) {
      state = state.copyWith(
        passwordReset: state.passwordReset.copyWith(errorMessage: 'Geçerli bir bağlantı bulunamadı.'),
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _service.resetPassword(token: token, newPassword: state.passwordReset.newPassword);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        step: LoginStep.passwordResetComplete,
        passwordReset: state.passwordReset.copyWith(
          errorMessage: null,
          token: null,
          newPassword: '',
          confirmPassword: '',
        ),
      );
    } on LoginException catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        passwordReset: state.passwordReset.copyWith(errorMessage: error.message),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        passwordReset: state.passwordReset.copyWith(
          errorMessage: 'Parolan güncellenemedi. Tekrar dene.',
        ),
      );
    }
  }

  Future<void> completePasskey({
    required String clientDataJson,
    required String authenticatorData,
    required String signature,
  }) async {
    if (state.step != LoginStep.passkey || state.isLoading || state.passkey.challengeId == null) {
      return;
    }
    if (!_featureFlags.webauthnPasskey) {
      state = state.copyWith(
        errorMessage: 'Passkey doğrulaması şu anda devre dışı.',
        step: LoginStep.mfaSelection,
      );
      return;
    }
    final identifier = state.credentials.identifier.trim();
    state = state.copyWith(isLoading: true, errorMessage: null);
    _emitLoginAttempt(
      identifier: identifier,
      success: null,
      reason: null,
      stage: 'passkey',
    );

    try {
      await _service.verifyPasskeyAssertion(
        identifier: identifier,
        challengeId: state.passkey.challengeId!,
        clientDataJson: clientDataJson,
        authenticatorData: authenticatorData,
        signature: signature,
      );
      _emitMfaSuccess(
        identifier: identifier,
        method: 'passkey',
      );
  await _completeLoginSuccess(identifier);
      return;
    } on LoginException catch (error) {
      await _handlePasskeyFailure(
        identifier: identifier,
        message: error.message,
        reason: error.code ?? 'invalid_passkey',
      );
    } catch (_) {
      await _handlePasskeyFailure(
        identifier: identifier,
        message: 'Passkey doğrulaması başarısız.',
        reason: 'passkey_verification_failed',
      );
    }
  }

  Future<void> confirmMagicLink() async {
    if (state.step != LoginStep.magicLink || state.isLoading) return;
    final identifier = state.credentials.identifier.trim();
    final token = state.magicLink.token;
    if (token == null) {
      state = state.copyWith(
        magicLink: state.magicLink.copyWith(errorMessage: 'Geçerli bir bağlantı bulunamadı.'),
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      magicLink: state.magicLink.copyWith(isVerifying: true, errorMessage: null),
    );
    _emitLoginAttempt(
      identifier: identifier,
      success: null,
      reason: null,
      stage: 'magic_link',
    );

    try {
      await _service.verifyMagicLink(token: token, identifier: identifier);
  await _completeLoginSuccess(identifier);
      return;
    } on LoginException catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        magicLink: state.magicLink.copyWith(
          isVerifying: false,
          errorMessage: error.message,
        ),
      );
      _emitLoginAttempt(
        identifier: identifier,
        success: false,
        reason: error.code ?? 'invalid_magic_link',
        stage: 'magic_link',
      );
      _emitLoginFailure(
        identifier: identifier,
        reason: error.code ?? 'invalid_magic_link',
        stage: 'magic_link',
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Bağlantı doğrulanamadı. Tekrar dene.',
        magicLink: state.magicLink.copyWith(
          isVerifying: false,
          errorMessage: 'Bağlantı doğrulanamadı. Tekrar dene.',
        ),
      );
      _emitLoginAttempt(
        identifier: identifier,
        success: false,
        reason: 'magic_link_verification_failed',
        stage: 'magic_link',
      );
      _emitLoginFailure(
        identifier: identifier,
        reason: 'magic_link_verification_failed',
        stage: 'magic_link',
      );
    }
  }

  void reset() {
    final sessionController = _sessionController;
    if (sessionController != null) {
      unawaited(sessionController.reset());
    }
    _sessionRefreshCoordinator?.clear();
    _credentialFailures = 0;
    _currentRoles = const {LoginAccountRole.user};
    state = LoginState.initial().copyWith(method: _firstEnabledMethod());
  }

  Future<void> _handleOtpFailure({
    required String identifier,
    required String message,
    required String reason,
  }) async {
    final attempts = (state.otp.attemptsRemaining - 1).clamp(0, 5);
    final sessionMetadata = _sessionBuilder();
    await _service.recordFailedAttempt(
      identifier: identifier,
      session: sessionMetadata,
      reason: reason,
    );
    final lock = await _service.getLockInfo(identifier);
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      errorMessage: message,
      otp: state.otp.copyWith(code: '', attemptsRemaining: attempts),
      lockInfo: lock,
      step: lock != null ? LoginStep.locked : LoginStep.otp,
    );
    _emitLoginAttempt(
      identifier: identifier,
      success: false,
      reason: reason,
      stage: 'otp',
      session: sessionMetadata,
    );
    _emitLoginFailure(
      identifier: identifier,
      reason: reason,
      stage: 'otp',
      session: sessionMetadata,
      attributes: {
        'remainingAttempts': attempts,
        'channel': state.otp.channel?.name,
        'lockRemainingAttempts': lock?.remainingAttempts,
        'lockUntil': lock?.until.toIso8601String(),
      },
    );
    if (lock != null) {
      _emitAccountLock(
        identifier: identifier,
        lock: lock,
        stage: 'otp',
        session: sessionMetadata,
      );
    }
  }

  Future<void> _handleTotpFailure({
    required String identifier,
    required String message,
    required String reason,
  }) async {
    final attempts = (state.totp.attemptsRemaining - 1).clamp(0, 5);
    final sessionMetadata = _sessionBuilder();
    await _service.recordFailedAttempt(
      identifier: identifier,
      session: sessionMetadata,
      reason: reason,
    );
    final lock = await _service.getLockInfo(identifier);
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      errorMessage: message,
      totp: state.totp.copyWith(code: '', attemptsRemaining: attempts),
      lockInfo: lock,
      step: lock != null ? LoginStep.locked : LoginStep.totp,
    );
    _emitLoginAttempt(
      identifier: identifier,
      success: false,
      reason: reason,
      stage: 'totp',
      session: sessionMetadata,
    );
    _emitLoginFailure(
      identifier: identifier,
      reason: reason,
      stage: 'totp',
      session: sessionMetadata,
      attributes: {
        'remainingAttempts': attempts,
        'lockRemainingAttempts': lock?.remainingAttempts,
        'lockUntil': lock?.until.toIso8601String(),
      },
    );
    if (lock != null) {
      _emitAccountLock(
        identifier: identifier,
        lock: lock,
        stage: 'totp',
        session: sessionMetadata,
      );
    }
  }

  Future<void> _handlePasskeyFailure({
    required String identifier,
    required String message,
    required String reason,
  }) async {
    final sessionMetadata = _sessionBuilder();
    await _service.recordFailedAttempt(
      identifier: identifier,
      session: sessionMetadata,
      reason: reason,
    );
    final lock = await _service.getLockInfo(identifier);
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      errorMessage: message,
      passkey: state.passkey.copyWith(isInProgress: false, errorMessage: message),
      lockInfo: lock,
      step: lock != null ? LoginStep.locked : LoginStep.passkey,
    );
    _emitLoginAttempt(
      identifier: identifier,
      success: false,
      reason: reason,
      stage: 'passkey',
      session: sessionMetadata,
    );
    _emitLoginFailure(
      identifier: identifier,
      reason: reason,
      stage: 'passkey',
      session: sessionMetadata,
      attributes: {
        'lockRemainingAttempts': lock?.remainingAttempts,
        'lockUntil': lock?.until.toIso8601String(),
      },
    );
    if (lock != null) {
      _emitAccountLock(
        identifier: identifier,
        lock: lock,
        stage: 'passkey',
        session: sessionMetadata,
      );
    }
  }

  TelemetryAttributes _baseTelemetryAttributes({
    required String identifier,
    required SessionMetadata metadata,
    required String stage,
  }) {
    final normalized = identifier.trim();
    final identifierHash = normalized.isEmpty ? 'unknown' : hashIdentifier(normalized);
    final attributes = <String, Object?>{
      'identifierHash': identifierHash,
      'stage': stage,
      'deviceIdHash': _deviceInfo.deviceIdHash,
      'trustedDevice': _deviceInfo.isTrusted,
      'ipHash': metadata.ipHash,
      'userAgent': metadata.userAgent,
      'locale': metadata.locale,
      'timeZone': metadata.timeZone,
    };
    attributes.removeWhere((_, value) => value == null);
    return attributes;
  }

  void _emitLoginAttempt({
    required String identifier,
    bool? success,
    String? reason,
    String stage = 'credentials',
    SessionMetadata? session,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final metadata = session ?? _sessionBuilder();
    final attributes = _baseTelemetryAttributes(
      identifier: identifier,
      metadata: metadata,
      stage: stage,
    )
      ..addAll({
        'status': success == null
            ? 'pending'
            : success
                ? 'success'
                : 'failure',
        'reason': reason,
        'method': state.method.name,
      });
    attributes.removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.loginAttempt,
          timestamp: _now(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _emitLoginFailure({
    required String identifier,
    required String reason,
    required String stage,
    SessionMetadata? session,
    Map<String, Object?>? attributes,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final metadata = session ?? _sessionBuilder();
    final payload = _baseTelemetryAttributes(
      identifier: identifier,
      metadata: metadata,
      stage: stage,
    )
      ..addAll({
        'reason': reason,
        'method': state.method.name,
      });
    if (attributes != null) {
      payload.addAll(attributes);
    }
    payload.removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.loginFailure,
          timestamp: _now(),
          attributes: payload,
        ),
      ),
    );
  }

  void _emitLoginSuccess({
    required String identifier,
    required bool rememberMe,
    required bool requiresDeviceVerification,
    required Duration sessionTtl,
    SessionMetadata? session,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final metadata = session ?? _sessionBuilder();
    final attributes = _baseTelemetryAttributes(
      identifier: identifier,
      metadata: metadata,
      stage: 'credentials',
    )
      ..addAll({
        'rememberMe': rememberMe,
        'requiresDeviceVerification': requiresDeviceVerification,
        'sessionTtlSeconds': sessionTtl.inSeconds,
        'method': state.method.name,
      });
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.loginSuccess,
          timestamp: _now(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _emitMfaChallenge({
    required String identifier,
    required List<MfaChannel> channels,
    required String source,
    SessionMetadata? session,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final metadata = session ?? _sessionBuilder();
    final attributes = _baseTelemetryAttributes(
      identifier: identifier,
      metadata: metadata,
      stage: 'mfa',
    )
      ..addAll({
        'channels': channels.map((channel) => channel.name).toList(growable: false),
        'channelCount': channels.length,
        'source': source,
      });
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.mfaChallenge,
          timestamp: _now(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _emitMfaSuccess({
    required String identifier,
    required String method,
    SessionMetadata? session,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final metadata = session ?? _sessionBuilder();
    final attributes = _baseTelemetryAttributes(
      identifier: identifier,
      metadata: metadata,
      stage: 'mfa',
    )
      ..addAll({'method': method});
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.mfaSuccess,
          timestamp: _now(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _emitCaptchaRequired({
    required String identifier,
    required int failedAttempts,
    SessionMetadata? session,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final metadata = session ?? _sessionBuilder();
    final attributes = _baseTelemetryAttributes(
      identifier: identifier,
      metadata: metadata,
      stage: 'credentials',
    )
      ..addAll({
        'failedAttempts': failedAttempts,
      });
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.captchaRequired,
          timestamp: _now(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _emitAccountLock({
    required String identifier,
    required LockInfo lock,
    required String stage,
    SessionMetadata? session,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final metadata = session ?? _sessionBuilder();
    final attributes = _baseTelemetryAttributes(
      identifier: identifier,
      metadata: metadata,
      stage: stage,
    )
      ..addAll({
        'lockReason': lock.reason,
        'unlockAt': lock.until.toIso8601String(),
        'remainingAttempts': lock.remainingAttempts,
      });
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.accountLock,
          timestamp: _now(),
          attributes: attributes,
        ),
      ),
    );
  }

  Future<void> _updateDeviceTrust({required bool trusted}) async {
    await _deviceFingerprintController?.markTrusted(trusted);
    final fingerprintState = _deviceFingerprintController?.state;
    if (fingerprintState != null) {
      final nextId = fingerprintState.deviceIdHash.isNotEmpty
          ? fingerprintState.deviceIdHash
          : _deviceInfo.deviceIdHash;
      _deviceInfo = DeviceInfo(
        deviceIdHash: nextId,
        isTrusted: fingerprintState.isTrusted,
      );
      return;
    }
    _deviceInfo = DeviceInfo(
      deviceIdHash: _deviceInfo.deviceIdHash,
      isTrusted: trusted,
    );
  }
}
