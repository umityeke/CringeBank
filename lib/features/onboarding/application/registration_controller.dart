import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cringebank/core/telemetry/telemetry_service.dart';
import 'package:cringebank/core/telemetry/telemetry_utils.dart';
import 'package:cringebank/services/email_otp_service.dart';
import 'package:cringebank/services/user_service.dart';

enum RegistrationFlowStep { email, otp, profile, success }

enum UsernameStatus { initial, dirty, checking, available, unavailable, error }

class RegistrationFlowState {
  const RegistrationFlowState({
    this.step = RegistrationFlowStep.email,
    this.isLoading = false,
    this.restorationComplete = false,
    this.requiresRegistration = true,
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.otpCode = '',
    this.otpError,
    this.otpResendAvailableAt,
    this.otpRemainingAttempts,
    this.sessionId,
    this.sessionExpiresAt,
    this.devOtp,
    this.username = '',
    this.usernameError,
    this.usernameStatus = UsernameStatus.initial,
    this.usernameTouched = false,
    this.fullName = '',
    this.acceptTerms = false,
    this.acceptPrivacy = false,
    this.marketingOptIn = false,
    this.globalMessage,
    this.completed = false,
  });

  final RegistrationFlowStep step;
  final bool isLoading;
  final bool restorationComplete;
  final bool requiresRegistration;
  final String email;
  final String password;
  final String confirmPassword;
  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;
  final String otpCode;
  final String? otpError;
  final DateTime? otpResendAvailableAt;
  final int? otpRemainingAttempts;
  final String? sessionId;
  final DateTime? sessionExpiresAt;
  final String? devOtp;
  final String username;
  final String? usernameError;
  final UsernameStatus usernameStatus;
  final bool usernameTouched;
  final String fullName;
  final bool acceptTerms;
  final bool acceptPrivacy;
  final bool marketingOptIn;
  final String? globalMessage;
  final bool completed;

  static RegistrationFlowState initial() => const RegistrationFlowState();

  bool get canResendOtp {
    if (otpResendAvailableAt == null) {
      return true;
    }
    return DateTime.now().isAfter(otpResendAvailableAt!);
  }

  Duration? get otpResendRemaining {
    if (otpResendAvailableAt == null) {
      return null;
    }
    final remaining = otpResendAvailableAt!.difference(DateTime.now());
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  bool get canSubmitProfile {
    final hasSession = sessionId != null && sessionId!.isNotEmpty;
    final usernameValid = username.isNotEmpty && usernameError == null;
    final usernameReady = usernameStatus == UsernameStatus.available;
    return !isLoading && hasSession && usernameValid && usernameReady && acceptTerms && acceptPrivacy;
  }

  RegistrationFlowState copyWith({
    RegistrationFlowStep? step,
    bool? isLoading,
    bool? restorationComplete,
    bool? requiresRegistration,
    String? email,
    String? password,
    String? confirmPassword,
    String? emailError,
    String? passwordError,
    String? confirmPasswordError,
    String? otpCode,
    String? otpError,
    DateTime? otpResendAvailableAt,
    int? otpRemainingAttempts,
    String? sessionId,
    DateTime? sessionExpiresAt,
    String? devOtp,
    String? username,
    String? usernameError,
    UsernameStatus? usernameStatus,
    bool? usernameTouched,
    String? fullName,
    bool? acceptTerms,
    bool? acceptPrivacy,
    bool? marketingOptIn,
    String? globalMessage,
    bool? completed,
  }) {
    return RegistrationFlowState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      restorationComplete: restorationComplete ?? this.restorationComplete,
      requiresRegistration: requiresRegistration ?? this.requiresRegistration,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      emailError: emailError,
      passwordError: passwordError,
      confirmPasswordError: confirmPasswordError,
      otpCode: otpCode ?? this.otpCode,
      otpError: otpError,
      otpResendAvailableAt: otpResendAvailableAt ?? this.otpResendAvailableAt,
      otpRemainingAttempts: otpRemainingAttempts ?? this.otpRemainingAttempts,
      sessionId: sessionId ?? this.sessionId,
      sessionExpiresAt: sessionExpiresAt ?? this.sessionExpiresAt,
      devOtp: devOtp ?? this.devOtp,
      username: username ?? this.username,
      usernameError: usernameError,
      usernameStatus: usernameStatus ?? this.usernameStatus,
      usernameTouched: usernameTouched ?? this.usernameTouched,
      fullName: fullName ?? this.fullName,
      acceptTerms: acceptTerms ?? this.acceptTerms,
      acceptPrivacy: acceptPrivacy ?? this.acceptPrivacy,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      globalMessage: globalMessage,
      completed: completed ?? this.completed,
    );
  }
}

class RegistrationController extends StateNotifier<RegistrationFlowState> {
  RegistrationController({UserService? userService, TelemetryService? telemetry, DateTime Function()? now})
      : _userService = userService ?? UserService.instance,
        _telemetry = telemetry,
        _now = now ?? DateTime.now,
        super(RegistrationFlowState.initial());

  final UserService _userService;
  final TelemetryService? _telemetry;
  final DateTime Function() _now;
  Timer? _usernameDebounce;

  String get _emailHash {
    final email = state.email.trim();
    if (email.isEmpty) {
      return 'unknown';
    }
    return hashIdentifier(email);
  }

  DateTime _timestamp() => _now().toUtc();

  TelemetryAttributes _baseAttributes(RegistrationFlowStep stage) {
    return <String, Object?>{
      'stage': stage.name,
      'stageIndex': stage.index,
      'identifierHash': _emailHash,
    };
  }

  void _recordStageViewed(RegistrationFlowStep stage, {String? reason}) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final attributes = _baseAttributes(stage)
      ..addAll({
        'reason': reason,
        'requiresRegistration': state.requiresRegistration,
      })
      ..removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.registrationStageViewed,
          timestamp: _timestamp(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _recordStepCompleted({
    required RegistrationFlowStep stage,
    Map<String, Object?>? extra,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final attributes = _baseAttributes(stage)
      ..addAll({
        'requiresRegistration': state.requiresRegistration,
        'marketingOptIn': stage == RegistrationFlowStep.profile ? state.marketingOptIn : null,
      });
    if (extra != null) {
      attributes.addAll(extra);
    }
    attributes.removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.registrationStepCompleted,
          timestamp: _timestamp(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _recordRegistrationFailure({
    required RegistrationFlowStep stage,
    required String reason,
    Map<String, Object?>? extra,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final attributes = _baseAttributes(stage)
      ..addAll({
        'reason': reason,
        'requiresRegistration': state.requiresRegistration,
      });
    if (extra != null) {
      attributes.addAll(extra);
    }
    attributes.removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.registrationFailure,
          timestamp: _timestamp(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _recordOtpResent({Map<String, Object?>? extra}) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final attributes = _baseAttributes(RegistrationFlowStep.otp)
      ..addAll({
        'requiresRegistration': state.requiresRegistration,
      });
    if (extra != null) {
      attributes.addAll(extra);
    }
    attributes.removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.registrationOtpResent,
          timestamp: _timestamp(),
          attributes: attributes,
        ),
      ),
    );
  }

  void _recordRegistrationCompleted({Map<String, Object?>? extra}) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final attributes = _baseAttributes(RegistrationFlowStep.success)
      ..addAll({
        'marketingOptIn': state.marketingOptIn,
        'hasFullName': state.fullName.isNotEmpty,
      });
    if (extra != null) {
      attributes.addAll(extra);
    }
    attributes.removeWhere((_, value) => value == null);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.registrationCompleted,
          timestamp: _timestamp(),
          attributes: attributes,
        ),
      ),
    );
  }

  String _deriveOtpFailureReason(EmailOtpVerificationResult result) {
    if (result.isExpired) {
      return 'otp_expired';
    }
    if (result.isTooManyAttempts) {
      return 'otp_rate_limited';
    }
    if (result.isNotFound) {
      return 'otp_not_found';
    }
    if (result.isInvalidCode) {
      return 'otp_invalid';
    }
    return 'otp_unknown_failure';
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    if (state.restorationComplete) {
      return;
    }
    state = state.copyWith(restorationComplete: true, requiresRegistration: true);
    _recordStageViewed(state.step, reason: 'initialize');
  }

  void resetFlow() {
    _usernameDebounce?.cancel();
    state = RegistrationFlowState.initial().copyWith(
      restorationComplete: true,
      requiresRegistration: true,
    );
    _recordStageViewed(state.step, reason: 'reset');
  }

  void updateEmail(String value) {
    state = state.copyWith(
      email: value.trim(),
      emailError: null,
    );
  }

  void updatePassword(String value) {
    state = state.copyWith(
      password: value,
      passwordError: null,
      confirmPasswordError: null,
    );
  }

  void updateConfirmPassword(String value) {
    state = state.copyWith(
      confirmPassword: value,
      confirmPasswordError: null,
    );
  }

  void updateOtpCode(String value) {
    state = state.copyWith(otpCode: value.trim(), otpError: null);
  }

  void updateUsername(String value) {
    final lower = value.toLowerCase();
    final sanitized = lower.replaceAll(RegExp(r'\s+'), '');
    _usernameDebounce?.cancel();

    state = state.copyWith(
      username: sanitized,
      usernameTouched: true,
      usernameStatus: UsernameStatus.dirty,
      usernameError: null,
    );

    final error = _validateUsername(sanitized);
    if (error != null) {
      state = state.copyWith(
        usernameError: error,
        usernameStatus: UsernameStatus.error,
      );
      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 450), () {
      _checkUsernameAvailability(sanitized);
    });
  }

  void updateFullName(String value) {
    state = state.copyWith(fullName: value.trim());
  }

  void toggleTerms(bool value) {
    state = state.copyWith(acceptTerms: value);
  }

  void togglePrivacy(bool value) {
    state = state.copyWith(acceptPrivacy: value);
  }

  void toggleMarketingOptIn(bool value) {
    state = state.copyWith(marketingOptIn: value);
  }

  Future<void> submitEmailStep() async {
    final email = state.email.trim();
    final password = state.password;
    final confirm = state.confirmPassword;

    String? emailError;
    String? passwordError;
    String? confirmError;

    if (!_isValidEmail(email)) {
      emailError = 'Lütfen geçerli bir e-posta adresi girin';
    }

    passwordError = _validatePassword(password);
    if (confirm.isEmpty) {
      confirmError = 'Şifre tekrar alanı gerekli';
    } else if (password != confirm) {
      confirmError = 'Şifreler eşleşmiyor';
    }

    if (emailError != null || passwordError != null || confirmError != null) {
      state = state.copyWith(
        emailError: emailError,
        passwordError: passwordError,
        confirmPasswordError: confirmError,
        globalMessage: null,
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.email,
        reason: 'validation_error',
        extra: {
          'emailValid': emailError == null,
          'passwordValid': passwordError == null,
          'confirmValid': confirmError == null,
        },
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      emailError: null,
      passwordError: null,
      confirmPasswordError: null,
      globalMessage: null,
    );

    try {
      final isAvailable = await _userService.isEmailAvailable(email);
      if (!isAvailable) {
        state = state.copyWith(
          isLoading: false,
          emailError: 'Bu e-posta zaten kullanılıyor',
        );
        _recordRegistrationFailure(
          stage: RegistrationFlowStep.email,
          reason: 'email_in_use',
        );
        return;
      }

      final otp = await EmailOtpService.sendOtp(email);
      final now = _now();
      state = state.copyWith(
        isLoading: false,
        step: RegistrationFlowStep.otp,
        otpCode: '',
        otpError: null,
        sessionId: null,
        sessionExpiresAt: null,
        otpResendAvailableAt: now.add(const Duration(seconds: 45)),
        otpRemainingAttempts: null,
        devOtp: kDebugMode ? otp ?? state.devOtp : null,
        requiresRegistration: true,
        globalMessage: 'Doğrulama kodu e-postana gönderildi',
      );
      _recordStepCompleted(
        stage: RegistrationFlowStep.email,
        extra: {
          'delivery': 'email',
          'passwordLength': password.length,
          'hadDebugOtp': kDebugMode && (otp?.isNotEmpty ?? false),
        },
      );
      _recordStageViewed(RegistrationFlowStep.otp, reason: 'otp_requested');
    } on FirebaseFunctionsException catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalMessage: error.message ?? 'Kod gönderilirken hata oluştu.',
      );
      final reason = (error.code.isNotEmpty ? error.code : 'otp_send_failed')
          .replaceAll(' ', '_');
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.email,
        reason: reason,
        extra: {
          'type': 'send_otp',
          'message': error.message,
        },
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalMessage: 'Kod gönderilirken hata oluştu: $error',
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.email,
        reason: 'unexpected_error',
        extra: {
          'type': 'send_otp',
          'errorType': error.runtimeType.toString(),
        },
      );
    }
  }

  Future<void> resendOtp() async {
    if (!state.canResendOtp) {
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.otp,
        reason: 'otp_resend_cooldown',
      );
      return;
    }
    final email = state.email.trim();
    if (email.isEmpty) {
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.otp,
        reason: 'email_missing',
      );
      return;
    }

    state = state.copyWith(isLoading: true, globalMessage: null);
    try {
      final otp = await EmailOtpService.resendOtp(email);
      final now = _now();
      state = state.copyWith(
        isLoading: false,
        otpResendAvailableAt: now.add(const Duration(seconds: 45)),
        globalMessage: 'Kod yeniden gönderildi',
        devOtp: kDebugMode ? otp ?? state.devOtp : state.devOtp,
      );
      _recordOtpResent(
        extra: {
          'delaySeconds': 45,
          'hadDebugOtp': kDebugMode && (otp?.isNotEmpty ?? false),
        },
      );
    } on FirebaseFunctionsException catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalMessage: error.message ?? 'Kod gönderilemedi.',
      );
      final reason = (error.code.isNotEmpty ? error.code : 'otp_resend_failed')
          .replaceAll(' ', '_');
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.otp,
        reason: reason,
        extra: {'type': 'otp_resend', 'message': error.message},
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalMessage: 'Kod gönderilemedi: $error',
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.otp,
        reason: 'unexpected_error',
        extra: {'type': 'otp_resend', 'errorType': error.runtimeType.toString()},
      );
    }
  }

  Future<void> verifyOtp() async {
    final code = state.otpCode.trim();
    if (code.length != 6) {
      state = state.copyWith(
        otpError: 'Lütfen 6 haneli kodu girin',
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.otp,
        reason: 'validation_error',
        extra: {'codeLength': code.length},
      );
      return;
    }

    final email = state.email.trim();
    if (email.isEmpty) {
      state = state.copyWith(
        otpError: 'E-posta doğrulaması için geri dönün',
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.otp,
        reason: 'email_missing',
      );
      return;
    }

    state = state.copyWith(isLoading: true, otpError: null, globalMessage: null);

    try {
      final result = await EmailOtpService.verifyOtp(email, code);
      if (!result.success) {
        final message = _mapOtpFailureToMessage(result);
        state = state.copyWith(
          isLoading: false,
          otpError: message,
          otpRemainingAttempts: result.remainingAttempts,
          sessionId: null,
          sessionExpiresAt: null,
        );
        _recordRegistrationFailure(
          stage: RegistrationFlowStep.otp,
          reason: _deriveOtpFailureReason(result),
          extra: {
            'remainingAttempts': result.remainingAttempts,
          },
        );
        return;
      }

      final sessionId = result.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          otpError: 'Doğrulama oturumu oluşturulamadı. Lütfen kodu yeniden iste.',
          sessionId: null,
          sessionExpiresAt: null,
        );
        _recordRegistrationFailure(
          stage: RegistrationFlowStep.otp,
          reason: 'session_missing',
        );
        return;
      }

      final expiresAt = result.sessionExpiresAt;
      final now = _now();
      if (expiresAt != null && expiresAt.isBefore(now)) {
        state = state.copyWith(
          isLoading: false,
          otpError: 'Doğrulama oturumunun süresi doldu. Lütfen kodu yeniden iste.',
          sessionId: null,
          sessionExpiresAt: null,
        );
        _recordRegistrationFailure(
          stage: RegistrationFlowStep.otp,
          reason: 'session_expired',
        );
        return;
      }

  final expiresIn = expiresAt?.difference(now).inSeconds;
      state = state.copyWith(
        isLoading: false,
        step: RegistrationFlowStep.profile,
        sessionId: sessionId,
        sessionExpiresAt: expiresAt,
        otpError: null,
        otpRemainingAttempts: null,
        globalMessage: 'E-posta doğrulandı, şimdi kullanıcı adı belirleyebilirsin',
      );
      _recordStepCompleted(
        stage: RegistrationFlowStep.otp,
        extra: {
          'sessionLifetimeSeconds': expiresIn,
          'hasExpiry': expiresAt != null,
        },
      );
      _recordStageViewed(RegistrationFlowStep.profile, reason: 'otp_verified');
    } on FirebaseFunctionsException catch (error) {
      state = state.copyWith(
        isLoading: false,
        otpError: error.message ?? 'Doğrulama başarısız',
      );
      final reason = (error.code.isNotEmpty ? error.code : 'otp_verify_failed')
          .replaceAll(' ', '_');
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.otp,
        reason: reason,
        extra: {'type': 'otp_verify', 'message': error.message},
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        otpError: 'Doğrulama başarısız: $error',
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.otp,
        reason: 'unexpected_error',
        extra: {'type': 'otp_verify', 'errorType': error.runtimeType.toString()},
      );
    }
  }

  Future<void> finalizeRegistration() async {
    if (!state.canSubmitProfile) {
      state = state.copyWith(globalMessage: 'Devam etmek için zorunlu alanları doldurun');
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.profile,
        reason: 'validation_error',
        extra: {
          'acceptTerms': state.acceptTerms,
          'acceptPrivacy': state.acceptPrivacy,
          'usernameStatus': state.usernameStatus.name,
        },
      );
      return;
    }

    final usernameError = _validateUsername(state.username);
    if (usernameError != null) {
      state = state.copyWith(
        usernameError: usernameError,
        usernameStatus: UsernameStatus.error,
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.profile,
        reason: 'invalid_username',
        extra: {'usernameLength': state.username.length},
      );
      return;
    }

    state = state.copyWith(isLoading: true, globalMessage: null);

    try {
      final success = await _userService.register(
        email: state.email,
        username: state.username,
        password: state.password,
        fullName: state.fullName,
        sessionId: state.sessionId!,
        marketingOptIn: state.marketingOptIn,
      );

      if (!success) {
        state = state.copyWith(
          isLoading: false,
          globalMessage: 'Hesap oluşturulamadı, lütfen tekrar deneyin',
        );
        _recordRegistrationFailure(
          stage: RegistrationFlowStep.profile,
          reason: 'registration_not_confirmed',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        step: RegistrationFlowStep.success,
        requiresRegistration: false,
        completed: true,
        globalMessage: 'Hesabın başarıyla oluşturuldu. Yönlendiriliyorsun...',
      );
      _recordStepCompleted(
        stage: RegistrationFlowStep.profile,
        extra: {
          'hasFullName': state.fullName.isNotEmpty,
          'usernameLength': state.username.length,
        },
      );
      _recordRegistrationCompleted(
        extra: {
          'usernameLength': state.username.length,
        },
      );
      _recordStageViewed(RegistrationFlowStep.success, reason: 'registration_completed');
    } on FirebaseFunctionsException catch (error) {
      final message = _mapRegistrationFinalizeError(error);
      final bool isUsernameConflict = error.code == 'already-exists' &&
          (error.details is Map && (error.details as Map)['field'] == 'username');
      state = state.copyWith(
        isLoading: false,
        globalMessage: message,
        usernameError: isUsernameConflict ? message : state.usernameError,
        usernameStatus: isUsernameConflict ? UsernameStatus.error : state.usernameStatus,
      );
      final reason = (error.code.isNotEmpty ? error.code : 'registration_failed')
          .replaceAll(' ', '_');
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.profile,
        reason: reason,
        extra: {
          'type': 'register',
          'isUsernameConflict': isUsernameConflict,
        },
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        globalMessage: 'Hesap oluşturulamadı: $error',
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.profile,
        reason: 'unexpected_error',
        extra: {
          'type': 'register',
          'errorType': error.runtimeType.toString(),
        },
      );
    }
  }

  void clearGlobalMessage() {
    if (state.globalMessage != null) {
      state = state.copyWith(globalMessage: null);
    }
  }

  bool _isValidEmail(String value) {
    if (value.isEmpty) {
      return false;
    }
    final normalized = value.toLowerCase();
    return normalized.contains('@') && normalized.length >= 5;
  }

  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Şifre en az 8 karakter olmalıdır';
    }
    if (!RegExp(r'[A-Za-zçğıöşüÇĞİÖŞÜ]').hasMatch(password)) {
      return 'Şifre en az bir harf içermelidir';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Şifre en az bir rakam içermelidir';
    }
    if (RegExp(r'\s').hasMatch(password)) {
      return 'Şifre boşluk karakteri içeremez';
    }
    return null;
  }

  String? _validateUsername(String username) {
    if (username.isEmpty) {
      return 'Kullanıcı adı gerekli.';
    }
    if (username.length < kRegistrationUsernameMinLength ||
        username.length > kRegistrationUsernameMaxLength) {
      return 'Kullanıcı adı $kRegistrationUsernameMinLength-$kRegistrationUsernameMaxLength karakter olmalıdır.';
    }
    if (!kRegistrationUsernamePattern.hasMatch(username)) {
      return 'Sadece harf, rakam, alt çizgi ve nokta kullanabilirsin.';
    }
    if (_isUsernameBanned(username)) {
      return 'Bu kullanıcı adı yasaklı listede. Lütfen farklı bir isim seç.';
    }
    return null;
  }

  bool _isUsernameBanned(String username) {
    final normalized = username.replaceAll(RegExp(r'[\._]'), '');
    for (final banned in kRegistrationBannedUsernameFragments) {
      if (normalized.contains(banned)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _checkUsernameAvailability(String username) async {
    state = state.copyWith(
      usernameStatus: UsernameStatus.checking,
      usernameError: null,
    );

    try {
      final available = await _userService.isUsernameAvailable(username);
      state = state.copyWith(
        usernameStatus: available ? UsernameStatus.available : UsernameStatus.unavailable,
        usernameError: available ? null : 'Bu kullanıcı adı zaten alınmış.',
      );
      if (!available) {
        _recordRegistrationFailure(
          stage: RegistrationFlowStep.profile,
          reason: 'username_unavailable',
          extra: {'usernameLength': username.length},
        );
      }
    } catch (_) {
      state = state.copyWith(
        usernameStatus: UsernameStatus.error,
        usernameError: 'Kullanıcı adı kontrolü sırasında bir hata oluştu.',
      );
      _recordRegistrationFailure(
        stage: RegistrationFlowStep.profile,
        reason: 'username_check_error',
      );
    }
  }

  String _mapOtpFailureToMessage(EmailOtpVerificationResult result) {
    if (result.isExpired) {
      return 'Kodun süresi dolmuş. Lütfen yeni bir kod iste.';
    }
    if (result.isTooManyAttempts) {
      return 'Çok fazla hatalı deneme yapıldı. Güvenlik için yeni kod istemen gerekiyor.';
    }
    if (result.isNotFound) {
      return 'Kod bulunamadı. Lütfen yeni bir kod gönder.';
    }
    if (result.isInvalidCode) {
      final remaining = result.remainingAttempts ?? 0;
      if (remaining > 0) {
        return 'Kod hatalı. $remaining deneme hakkın kaldı.';
      }
      return 'Kod hatalı. Lütfen yeni bir kod iste.';
    }
    return 'Kod doğrulanamadı. Lütfen tekrar dene.';
  }

  String _mapRegistrationFinalizeError(FirebaseFunctionsException error) {
    final details = error.details;
    String? field;
    List<String> reasons = const [];

    if (details is Map) {
      field = details['field']?.toString();
      final detailReasons = details['reasons'];
      if (detailReasons is List) {
        reasons = detailReasons
            .whereType<String>()
            .map((reason) => reason.trim())
            .where((reason) => reason.isNotEmpty)
            .toList(growable: false);
      }
    }

    if (reasons.isNotEmpty) {
      return reasons.first;
    }

    switch (error.code) {
      case 'already-exists':
        if (field == 'username') {
          return 'Bu kullanıcı adı zaten alınmış.';
        }
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'failed-precondition':
        return 'Doğrulama oturumu geçersiz veya süresi doldu. Lütfen e-postanı yeniden doğrula.';
      case 'invalid-argument':
        return 'Gönderilen bilgiler doğrulanamadı. Lütfen alanları kontrol et.';
      case 'permission-denied':
        return 'Bu işlemi gerçekleştirme iznin yok.';
      default:
        return error.message ?? 'Kayıt işlemi tamamlanamadı. Lütfen tekrar dene.';
    }
  }
}

const int kRegistrationUsernameMinLength = 3;
const int kRegistrationUsernameMaxLength = 32;
final RegExp kRegistrationUsernamePattern = RegExp(r'^[a-z0-9_\.]+$');
const Set<String> kRegistrationBannedUsernameFragments = {
  'admin',
  'administrator',
  'root',
  'support',
  'help',
  'mod',
  'moderator',
  'staff',
  'bank',
  'cringe',
  'system',
  'official',
};
