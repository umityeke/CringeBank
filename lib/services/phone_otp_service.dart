import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

enum PhoneOtpFailureReason {
  invalidCode,
  expired,
  notFound,
  tooManyAttempts,
  unknown,
}

class PhoneOtpVerificationResult {
  const PhoneOtpVerificationResult({
    required this.success,
    this.reason,
    this.remainingAttempts,
  });

  factory PhoneOtpVerificationResult.fromResponse(dynamic response) {
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final success = map['success'] == true;
      final reason = success
          ? null
          : _failureReasonFromString(map['reason']?.toString());
      final remaining = map['remainingAttempts'];
      return PhoneOtpVerificationResult(
        success: success,
        reason: reason,
        remainingAttempts: remaining is num ? remaining.toInt() : null,
      );
    }

    if (response is bool) {
      return PhoneOtpVerificationResult(success: response);
    }

    if (response is String) {
      final normalized = response.toLowerCase();
      return PhoneOtpVerificationResult(success: normalized == 'true');
    }

    return const PhoneOtpVerificationResult(
      success: false,
      reason: PhoneOtpFailureReason.unknown,
    );
  }

  final bool success;
  final PhoneOtpFailureReason? reason;
  final int? remainingAttempts;

  bool get isInvalidCode => reason == PhoneOtpFailureReason.invalidCode;
  bool get isExpired => reason == PhoneOtpFailureReason.expired;
  bool get isNotFound => reason == PhoneOtpFailureReason.notFound;
  bool get isTooManyAttempts => reason == PhoneOtpFailureReason.tooManyAttempts;
}

class PhoneOtpService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static Future<String?> sendOtp(String phoneNumber) async {
    final normalizedPhone = _normalizePhone(phoneNumber);

    try {
      final callable = _functions.httpsCallable('sendPhoneOtp');
      final result = await callable.call({'phoneNumber': normalizedPhone});
      if (result.data == null) return null;
      if (result.data is Map) {
        final map = Map<String, dynamic>.from(result.data as Map);
        return map['debugCode']?.toString();
      }
      return result.data.toString();
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint('Cloud Function sendPhoneOtp failed: ${e.message}\n$stack');
      rethrow;
    } catch (e, stack) {
      debugPrint('Unexpected error calling sendPhoneOtp: $e\n$stack');
      rethrow;
    }
  }

  static Future<PhoneOtpVerificationResult> confirmPhoneUpdate(
    String phoneNumber,
    String code,
  ) async {
    final normalizedPhone = _normalizePhone(phoneNumber);
    final sanitizedCode = code.trim();

    try {
      final callable = _functions.httpsCallable('confirmPhoneUpdate');
      final result = await callable.call({
        'phoneNumber': normalizedPhone,
        'code': sanitizedCode,
      });
      return PhoneOtpVerificationResult.fromResponse(result.data);
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint('Cloud Function confirmPhoneUpdate failed: ${e.message}\n$stack');
      rethrow;
    } catch (e, stack) {
      debugPrint('Unexpected error calling confirmPhoneUpdate: $e\n$stack');
      rethrow;
    }
  }

  static String _normalizePhone(String phoneNumber) => phoneNumber.trim();
}

PhoneOtpFailureReason? _failureReasonFromString(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  switch (value) {
    case 'invalid-code':
      return PhoneOtpFailureReason.invalidCode;
    case 'expired':
      return PhoneOtpFailureReason.expired;
    case 'not-found':
      return PhoneOtpFailureReason.notFound;
    case 'too-many-attempts':
      return PhoneOtpFailureReason.tooManyAttempts;
    default:
      return PhoneOtpFailureReason.unknown;
  }
}
