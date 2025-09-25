import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailOtpService {
  static const _collection = 'email_otps';
  static const _maxAttempts = 5;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  static const _httpEndpoint =
      'https://europe-west1-cringe-bank.cloudfunctions.net/sendEmailOtpHttp';

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
      Uri.parse(_httpEndpoint),
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

  static Future<bool> verifyOtp(String email, String code) async {
    final normalizedEmail = _normalizeEmail(email);
    final docRef = _firestore.collection(_collection).doc(normalizedEmail);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.data() ?? {};
    final attempts = (data['attempts'] as num?)?.toInt() ?? 0;

    if (attempts >= _maxAttempts) {
      await docRef.delete();
      return false;
    }

    final Timestamp? expiresTimestamp = data['expiresAt'] as Timestamp?;
    final DateTime? expiresAt = expiresTimestamp?.toDate();

    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      await docRef.delete();
      return false;
    }

    final storedHash = data['hash'] as String?;
    final incomingHash = _hashCode(normalizedEmail, code);

    if (storedHash != null && storedHash == incomingHash) {
      await docRef.delete();
      return true;
    }

    try {
      await docRef.update({
        'attempts': FieldValue.increment(1),
        'lastAttemptAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, stack) {
      debugPrint(
        'Failed to update OTP attempts for $normalizedEmail: ${e.message}\n$stack',
      );
      rethrow;
    } catch (e, stack) {
      debugPrint(
        'Unexpected error while updating OTP attempts for $normalizedEmail: $e\n$stack',
      );
      rethrow;
    }
    return false;
  }

  static String _hashCode(String email, String code) {
    final normalized = _normalizeEmail(email);
    final bytes = utf8.encode('$normalized|$code');
    return sha256.convert(bytes).toString();
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();
}
