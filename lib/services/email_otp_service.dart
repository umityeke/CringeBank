import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      if (kIsWeb) {
        return await _sendOtpViaHttp(normalizedEmail);
      }

      return await _sendOtpViaCallable(normalizedEmail);
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint('Cloud Function sendEmailOtp failed: ${e.message}\n$stack');
      rethrow;
    } catch (e, stack) {
      debugPrint('Unexpected error calling sendEmailOtp: $e\n$stack');
      rethrow;
    }
  }

  static Future<String?> _sendOtpViaCallable(String email) async {
    final callable = _functions.httpsCallable('sendEmailOtp');
    final result = await callable.call({'email': email});
    if (result.data == null) return null;
    if (result.data is Map) {
      final map = Map<String, dynamic>.from(result.data as Map);
      return map['debugCode']?.toString();
    }
    return result.data.toString();
  }

  static Future<String?> _sendOtpViaHttp(String email) async {
    final response = await http.post(
      Uri.parse(_sendOtpHttpEndpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    Map<String, dynamic>? payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (error, stack) {
        debugPrint('OTP HTTP yanıtı JSON değil: $error\n$stack');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
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
      final dynamic response = kIsWeb
          ? await _verifyOtpViaHttp(normalizedEmail, sanitizedCode)
          : await _verifyOtpViaCallable(normalizedEmail, sanitizedCode);

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

    try {
      final callable = _functions.httpsCallable('confirmEmailUpdate');
      final result = await callable.call({
        'email': normalizedEmail,
        'code': sanitizedCode,
      });
      return EmailOtpVerificationResult.fromResponse(result.data);
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint('Cloud Function confirmEmailUpdate failed: ${e.message}\n$stack');
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
    final callable = _functions.httpsCallable('verifyEmailOtp');
    final result = await callable.call({'email': email, 'code': code});
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
}
