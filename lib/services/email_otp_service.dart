import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'telemetry/callable_latency_tracker.dart';

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
  });

  factory EmailOtpVerificationResult.fromResponse(dynamic response) {
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final success = map['success'] == true;
      final reason = success
          ? null
          : _failureReasonFromString(map['reason']?.toString());
      final remaining = map['remainingAttempts'];
      return EmailOtpVerificationResult(
        success: success,
        reason: reason,
        remainingAttempts: remaining is num ? remaining.toInt() : null,
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

  static const _sendOtpHttpEndpoint =
      'https://europe-west1-cringe-bank.cloudfunctions.net/sendEmailOtpHttp';
  static const _verifyOtpHttpEndpoint =
      'https://europe-west1-cringe-bank.cloudfunctions.net/verifyEmailOtpHttp';

  static Future<String?> sendOtp(String email) async {
    final normalizedEmail = _normalizeEmail(email);

    try {
      if (!_supportsCallableFunctions) {
        return await _sendOtpViaHttp(normalizedEmail);
      }

      try {
        return await _sendOtpViaCallable(normalizedEmail);
      } on MissingPluginException catch (error, stack) {
        _logMissingPluginFallback('sendEmailOtp', error, stack);
        return await _sendOtpViaHttp(normalizedEmail);
      }
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
    http.Response response;
    try {
      response = await http.post(
        Uri.parse(_sendOtpHttpEndpoint),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
    } catch (error, stack) {
      final logMsg = 'sendEmailOtpHttp isteği gönderilemedi: $error\n$stack';
      developer.log(logMsg, name: 'EmailOtpService');
      debugPrint(logMsg);
      // ignore: avoid_print
      print(logMsg);
      rethrow;
    }

    Map<String, dynamic>? payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (error, stack) {
        final logMsg = 'OTP HTTP yanıtı JSON değil: $error\n$stack';
        developer.log(logMsg, name: 'EmailOtpService');
        debugPrint(logMsg);
        // ignore: avoid_print
        print(logMsg);
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
          : 'Doğrulama e-postası gönderilemedi.';
      throw FirebaseFunctionsException(
        code: code,
        message: message,
        details: payload,
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
        response = await _verifyOtpViaHttp(normalizedEmail, sanitizedCode);
      } else {
        try {
          response = await _verifyOtpViaCallable(
            normalizedEmail,
            sanitizedCode,
          );
        } on MissingPluginException catch (error, stack) {
          _logMissingPluginFallback('verifyEmailOtp', error, stack);
          response = await _verifyOtpViaHttp(normalizedEmail, sanitizedCode);
        }
      }

      return EmailOtpVerificationResult.fromResponse(response);
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint('Cloud Function verifyEmailOtp failed: ${e.message}\n$stack');
      rethrow;
    } catch (e, stack) {
      debugPrint('Unexpected error calling verifyEmailOtp: $e\n$stack');
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

  static Future<dynamic> _verifyOtpViaCallable(
    String email,
    String code,
  ) async {
    final result = await _functions.callWithLatency<dynamic>(
      'verifyEmailOtp',
      payload: {'email': email, 'code': code},
      category: 'emailOtp',
    );
    return result.data;
  }

  static Future<dynamic> _verifyOtpViaHttp(String email, String code) async {
    final response = await http.post(
      Uri.parse(_verifyOtpHttpEndpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

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

  static bool get _supportsCallableFunctions {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
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
