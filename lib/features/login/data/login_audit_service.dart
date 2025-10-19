import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../../../services/telemetry/callable_latency_tracker.dart';
import '../domain/models/login_models.dart';

/// Handles audit side-effects for successful login attempts.
///
/// The implementation updates Firestore with the latest login timestamp
/// and forwards a structured event to the Azure SQL gateway via Cloud
/// Functions. Failures are swallowed after logging because login success
/// should not be blocked by telemetry data issues.
class LoginAuditService {
  LoginAuditService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    firebase_auth.FirebaseAuth? auth,
    DateTime Function()? now,
  })  : _firestoreInstance = firestore,
        _functionsInstance = functions,
        _authInstance = auth,
        _now = now ?? DateTime.now;

  FirebaseFirestore? _firestoreInstance;
  FirebaseFunctions? _functionsInstance;
  firebase_auth.FirebaseAuth? _authInstance;
  final DateTime Function() _now;

  FirebaseFirestore? get _firestore {
    if (_firestoreInstance != null) {
      return _firestoreInstance;
    }
    try {
      _firestoreInstance = FirebaseFirestore.instance;
    } catch (error) {
      debugPrint('LoginAuditService Firestore unavailable: $error');
      return null;
    }
    return _firestoreInstance;
  }

  FirebaseFunctions? get _functions {
    if (_functionsInstance != null) {
      return _functionsInstance;
    }
    try {
      _functionsInstance =
          FirebaseFunctions.instanceFor(region: 'europe-west1');
    } catch (error) {
      debugPrint('LoginAuditService Functions unavailable: $error');
      return null;
    }
    return _functionsInstance;
  }

  firebase_auth.FirebaseAuth? get _auth {
    if (_authInstance != null) {
      return _authInstance;
    }
    try {
      _authInstance = firebase_auth.FirebaseAuth.instance;
    } catch (error) {
      debugPrint('LoginAuditService Auth unavailable: $error');
      return null;
    }
    return _authInstance;
  }

  Future<void> recordSuccessfulLogin({
    required String identifier,
    required SessionMetadata session,
    required String deviceIdHash,
    required bool isTrustedDevice,
    required bool rememberMe,
    required bool requiresDeviceVerification,
  }) async {
    final trimmedIdentifier = identifier.trim();
    if (trimmedIdentifier.isEmpty) {
      return;
    }

    final firestore = _firestore;
    final functions = _functions;
    if (firestore == null && functions == null) {
      return;
    }

    final futures = <Future<void>>[];
    if (firestore != null) {
      futures.add(
        _updateFirestoreLastLogin(
          firestore: firestore,
          identifier: trimmedIdentifier,
        ),
      );
    }

    if (functions != null) {
      futures.add(
        _recordSqlLoginEvent(
          functions: functions,
          identifier: trimmedIdentifier,
          session: session,
          deviceIdHash: deviceIdHash,
          isTrustedDevice: isTrustedDevice,
          rememberMe: rememberMe,
          requiresDeviceVerification: requiresDeviceVerification,
        ),
      );
    }

    if (futures.isEmpty) {
      return;
    }

    await Future.wait(futures);
  }

  Future<void> _updateFirestoreLastLogin({
    required FirebaseFirestore firestore,
    required String identifier,
  }) async {
    try {
      final userDocId = await _resolveUserDocumentId(
        firestore: firestore,
        identifier: identifier,
      );
      if (userDocId == null) {
        debugPrint(
          'LoginAuditService could not resolve userId for identifier=$identifier',
        );
        return;
      }
      await firestore.collection('users').doc(userDocId).set(
        {
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error, stackTrace) {
      debugPrint('LoginAuditService lastLoginAt update failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _recordSqlLoginEvent({
    required FirebaseFunctions functions,
    required String identifier,
    required SessionMetadata session,
    required String deviceIdHash,
    required bool isTrustedDevice,
    required bool rememberMe,
    required bool requiresDeviceVerification,
  }) async {
    final payload = <String, dynamic>{
      'identifier': identifier,
      'deviceIdHash': deviceIdHash,
      'isTrustedDevice': isTrustedDevice,
      'rememberMe': rememberMe,
      'requiresDeviceVerification': requiresDeviceVerification,
      'ipHash': session.ipHash,
      'userAgent': session.userAgent,
      'locale': session.locale,
      'timeZone': session.timeZone,
      'eventAt': _now().toUtc().toIso8601String(),
      'source': 'flutter-app',
    };
    try {
      await functions.callWithLatency<dynamic>(
        'sqlGatewayLoginEventsRecord',
        payload: payload,
        category: 'authSqlGateway',
      );
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'LoginAuditService SQL event failed: ${error.code} ${error.message}',
      );
    } catch (error, stackTrace) {
      debugPrint('LoginAuditService SQL event error: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<String?> _resolveUserDocumentId({
    required FirebaseFirestore firestore,
    required String identifier,
  }) async {
    final auth = _auth;
    final firebaseUser = auth?.currentUser;
    if (firebaseUser != null && firebaseUser.uid.isNotEmpty) {
      return firebaseUser.uid;
    }

    try {
      final directDoc = await firestore.collection('users').doc(identifier).get();
      if (directDoc.exists) {
        return directDoc.id;
      }
    } catch (error) {
      debugPrint(
        'LoginAuditService direct user doc lookup failed for $identifier: $error',
      );
    }

    final normalized = identifier.toLowerCase();

    try {
      final emailQuery = await firestore
          .collection('users')
          .where('emailLower', isEqualTo: normalized)
          .limit(1)
          .get();
      if (emailQuery.docs.isNotEmpty) {
        return emailQuery.docs.first.id;
      }
    } catch (error) {
      debugPrint(
        'LoginAuditService emailLower lookup failed for $identifier: $error',
      );
    }

    try {
      final usernameQuery = await firestore
          .collection('users')
          .where('usernameLower', isEqualTo: normalized)
          .limit(1)
          .get();
      if (usernameQuery.docs.isNotEmpty) {
        return usernameQuery.docs.first.id;
      }
    } catch (error) {
      debugPrint(
        'LoginAuditService usernameLower lookup failed for $identifier: $error',
      );
    }

    return null;
  }
}
