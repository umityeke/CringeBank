import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/platform_info.dart';

import 'telemetry/callable_latency_tracker.dart';
import 'telemetry/trace_http_client.dart';

enum EmailOtpFailureReason {
  invalidCode,
  expired,
  notFound,
  tooManyAttempts,
  unknown,
}

class EmailOtpVerificationResult {
  const EmailOtpVerificationResult({
    required this.success,
    this.reason,
    this.remainingAttempts,
    this.sessionId,
    this.sessionExpiresAt,
  });

  factory EmailOtpVerificationResult.fromResponse(dynamic response) {
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final success = map['success'] == true;
      final reason = success
          ? null
          : _failureReasonFromString(map['reason']?.toString());
      final remaining = map['remainingAttempts'];
      final sessionId = map['sessionId']?.toString();
      final expiresRaw = map['expiresAt'] ?? map['sessionExpiresAt'];
      DateTime? sessionExpiresAt;
      if (expiresRaw is String && expiresRaw.isNotEmpty) {
        sessionExpiresAt = DateTime.tryParse(expiresRaw);
      }
      return EmailOtpVerificationResult(
        success: success,
        reason: reason,
        remainingAttempts: remaining is num ? remaining.toInt() : null,
        sessionId: sessionId?.isEmpty == true ? null : sessionId,
        sessionExpiresAt: sessionExpiresAt,
      );
    }

    if (response is bool) {
      return EmailOtpVerificationResult(success: response);
    }

    if (response is String) {
      final normalized = response.toLowerCase();
      return EmailOtpVerificationResult(success: normalized == 'true');
    }

    return const EmailOtpVerificationResult(
      success: false,
      reason: EmailOtpFailureReason.unknown,
    );
  }

  final bool success;
  final EmailOtpFailureReason? reason;
  final int? remainingAttempts;
  final String? sessionId;
  final DateTime? sessionExpiresAt;

  bool get isInvalidCode => reason == EmailOtpFailureReason.invalidCode;
  bool get isExpired => reason == EmailOtpFailureReason.expired;
  bool get isNotFound => reason == EmailOtpFailureReason.notFound;
  bool get isTooManyAttempts => reason == EmailOtpFailureReason.tooManyAttempts;
}

EmailOtpFailureReason? _failureReasonFromString(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  switch (value) {
    case 'invalid-code':
      return EmailOtpFailureReason.invalidCode;
    case 'expired':
      return EmailOtpFailureReason.expired;
    case 'not-found':
      return EmailOtpFailureReason.notFound;
    case 'too-many-attempts':
      return EmailOtpFailureReason.tooManyAttempts;
    default:
      return EmailOtpFailureReason.unknown;
  }
}

class EmailOtpService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  static final TraceHttpClient _traceClient = TraceHttpClient.shared;

  // Emulator mode: use localhost URLs when kDebugMode
  static String get _sendOtpHttpEndpoint => kDebugMode
      ? 'http://127.0.0.1:5001/cringe-bank/europe-west1/sendEmailOtpHttp'
      : 'https://europe-west1-cringe-bank.cloudfunctions.net/sendEmailOtpHttp';
  
  static String get _registrationVerifyOtpHttpEndpoint => kDebugMode
      ? 'http://127.0.0.1:5001/cringe-bank/europe-west1/registrationVerifyOtpHttp'
      : 'https://europe-west1-cringe-bank.cloudfunctions.net/registrationVerifyOtpHttp';

  static Future<String?> sendOtp(String email) async {
    final normalizedEmail = _normalizeEmail(email);

    try {
      if (_supportsCallableFunctions) {
        try {
          return await _sendOtpViaCallable(normalizedEmail);
        } on MissingPluginException catch (error, stack) {
          _logMissingPluginFallback('sendEmailOtp', error, stack);
        } on PlatformException catch (error, stack) {
          if (_shouldFallbackFromPlatformException(error)) {
            debugPrint(
              'Callable sendEmailOtp platform hatası, HTTP fallback deneniyor: '
              '$error\n$stack',
            );
          } else {
            rethrow;
          }
        } on FirebaseFunctionsException catch (error, stack) {
          if (_shouldFallbackFromFunctionsException(error)) {
            debugPrint(
              'Callable sendEmailOtp beklenmedik hata döndürdü, HTTP fallback '
              'deneniyor: $error\n$stack',
            );
          } else {
            rethrow;
          }
        }
      }

      return await _sendOtpViaHttp(normalizedEmail);
    } on FirebaseFunctionsException catch (e, stack) {
      Object? encodedDetails;
      try {
        encodedDetails = e.details == null ? null : jsonEncode(e.details);
      } catch (_) {
        encodedDetails = e.details;
      }
      final logMessage =
          'Cloud Function sendEmailOtp failed [${e.code}]: ${e.message} (details: $encodedDetails)';
      debugPrint('$logMessage\n$stack');
      // ignore: avoid_print
      print(logMessage);
      rethrow;
    } catch (e, stack) {
      debugPrint('Unexpected error calling sendEmailOtp: $e\n$stack');
      rethrow;
    }
  }

  static Future<String?> _sendOtpViaCallable(String email) async {
    final result = await _functions.callWithLatency<dynamic>(
      'sendEmailOtp',
      payload: {'email': email},
      category: 'emailOtp',
    );
    if (result.data == null) return null;
    if (result.data is Map) {
      final map = Map<String, dynamic>.from(result.data as Map);
      return map['debugCode']?.toString();
    }
    return result.data.toString();
  }

  static Future<String?> _sendOtpViaHttp(String email) async {
    TraceHttpResponse traceResponse;
    try {
      traceResponse = await _traceClient.postJson(
        Uri.parse(_sendOtpHttpEndpoint),
        jsonBody: {'email': email},
        operation: 'emailOtp.send',
      );
    } catch (error, stack) {
      final logMsg = 'sendEmailOtpHttp isteği gönderilemedi: $error\n$stack';
      developer.log(logMsg, name: 'EmailOtpService');
      debugPrint(logMsg);
      // ignore: avoid_print
      print(logMsg);
      rethrow;
    }

    final response = traceResponse.response;

    Map<String, dynamic>? payload;
    Map<String, dynamic>? nonJsonDetails;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (error, stack) {
        final snippet = response.body.length > 512
            ? '${response.body.substring(0, 512)}…'
            : response.body;
        final logMsg =
            'OTP HTTP yanıtı JSON değil: $error\n--- BODY (${response.body.length} bytes) ---\n$snippet\n------------------------------\n$stack';
        developer.log(logMsg, name: 'EmailOtpService');
        debugPrint(logMsg);
        // ignore: avoid_print
        print(logMsg);
        nonJsonDetails = {
          'contentType': response.headers['content-type'] ?? 'unknown',
          'status': response.statusCode,
          'bodyPreview': snippet,
        };
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final debugPayload = () {
        if (payload == null) return 'null';
        try {
          return jsonEncode(payload);
        } catch (_) {
          return payload.toString();
        }
      }();
      final logMessage =
          'sendEmailOtpHttp başarısız yanıt: status=${response.statusCode}, payload=$debugPayload';
      developer.log(logMessage, name: 'EmailOtpService');
      debugPrint(logMessage);
      // ignore: avoid_print
      print(logMessage);
      final code = payload != null
          ? payload['error']?.toString() ?? 'internal'
          : 'internal';
      final message = payload != null
          ? payload['message']?.toString() ??
                'Doğrulama e-postası gönderilemedi.'
          : nonJsonDetails != null
              ? 'Doğrulama e-postası gönderilemedi. Sunucu JSON dışı içerik döndürdü.'
              : 'Doğrulama e-postası gönderilemedi.';
      throw FirebaseFunctionsException(
        code: code,
        message: message,
        details: payload ?? nonJsonDetails,
      );
    }

    if (payload == null) {
      return null;
    }

    return payload['debugCode']?.toString();
  }

  static Future<String?> resendOtp(String email) async {
    return sendOtp(email);
  }

  static Future<EmailOtpVerificationResult> verifyOtp(
    String email,
    String code,
  ) async {
    final normalizedEmail = _normalizeEmail(email);
    final sanitizedCode = code.trim();

    try {
      dynamic response;
      if (!_supportsCallableFunctions) {
        response = await _registrationVerifyOtpViaHttp(
          normalizedEmail,
          sanitizedCode,
        );
      } else {
        try {
          response = await _registrationVerifyOtpViaCallable(
            normalizedEmail,
            sanitizedCode,
          );
        } on MissingPluginException catch (error, stack) {
          _logMissingPluginFallback('registrationVerifyOtp', error, stack);
          response = await _registrationVerifyOtpViaHttp(
            normalizedEmail,
            sanitizedCode,
          );
        }
      }

      return EmailOtpVerificationResult.fromResponse(response);
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint(
        'Cloud Function registrationVerifyOtp failed: ${e.message}\n$stack',
      );
      rethrow;
    } catch (e, stack) {
      debugPrint('Unexpected error calling registrationVerifyOtp: $e\n$stack');
      rethrow;
    }
  }

  static Future<EmailOtpVerificationResult> confirmEmailUpdate(
    String email,
    String code,
  ) async {
    final normalizedEmail = _normalizeEmail(email);
    final sanitizedCode = code.trim();

    if (!_supportsCallableFunctions) {
      throw FirebaseFunctionsException(
        code: 'unimplemented',
        message: 'Bu platformda e-posta güncelleme doğrulaması desteklenmiyor.',
      );
    }

    try {
      final result = await _functions.callWithLatency<dynamic>(
        'confirmEmailUpdate',
        payload: {'email': normalizedEmail, 'code': sanitizedCode},
        category: 'emailOtp',
      );
      return EmailOtpVerificationResult.fromResponse(result.data);
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint(
        'Cloud Function confirmEmailUpdate failed: ${e.message}\n$stack',
      );
      rethrow;
    } catch (e, stack) {
      debugPrint('Unexpected error calling confirmEmailUpdate: $e\n$stack');
      rethrow;
    }
  }

  static Future<dynamic> _registrationVerifyOtpViaCallable(
    String email,
    String code,
  ) async {
    final result = await _functions.callWithLatency<dynamic>(
      'registrationVerifyOtp',
      payload: {'email': email, 'code': code},
      category: 'emailOtp',
    );
    return result.data;
  }

  static Future<dynamic> _registrationVerifyOtpViaHttp(
    String email,
    String code,
  ) async {
    final traceResponse = await _traceClient.postJson(
      Uri.parse(_registrationVerifyOtpHttpEndpoint),
      jsonBody: {'email': email, 'code': code},
      operation: 'emailOtp.verifyHttp',
    );

    final response = traceResponse.response;

    Map<String, dynamic>? payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (error, stack) {
        debugPrint('OTP doğrulama HTTP yanıtı JSON değil: $error\n$stack');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final codeValue = payload != null
          ? payload['error']?.toString() ?? 'internal'
          : 'internal';
      final message = payload != null
          ? payload['message']?.toString() ?? 'Doğrulama işlemi tamamlanamadı.'
          : 'Doğrulama işlemi tamamlanamadı.';
      throw FirebaseFunctionsException(
        code: codeValue,
        message: message,
        details: payload,
      );
    }

    return payload;
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static bool get _supportsCallableFunctions => PlatformInfo.isMobile;

  static bool _shouldFallbackFromPlatformException(PlatformException error) {
  if (error.code == 'MissingPluginException' ||
    error.code == 'unimplemented') {
      return true;
    }

    final message = error.message?.toLowerCase() ?? '';
    return message.contains('missingpluginexception') ||
    message.contains('unimplemented') ||
    message.contains('unable to establish connection on channel');
  }

  static bool _shouldFallbackFromFunctionsException(
    FirebaseFunctionsException error,
  ) {
    if (error.code == 'unimplemented') {
      return true;
    }

    final message = error.message?.toLowerCase() ?? '';
    return message.contains('unable to establish connection on channel') ||
        message.contains('missing plugin') ||
        message.contains('unimplemented');
  }

  static void _logMissingPluginFallback(
    String functionName,
    MissingPluginException error,
    StackTrace stack,
  ) {
    final message =
        'Callable Firebase Functions $functionName platform kanalını bulamadı, HTTP fallback kullanılacak.';
    developer.log(
      message,
      name: 'EmailOtpService',
      error: error,
      stackTrace: stack,
    );
    debugPrint('$message\n$error');
  }
}
