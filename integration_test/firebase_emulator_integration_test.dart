import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:cringebank/firebase_options.dart';

class _HostPort {
  const _HostPort(this.host, this.port);

  final String host;
  final int port;

  @override
  String toString() => '$host:$port';
}

_HostPort _resolveEndpoint({
  required String? envValue,
  required int defaultPort,
  String defaultHost = 'localhost',
}) {
  final value = envValue;
  if (value == null || value.isEmpty) {
    return _HostPort(defaultHost, defaultPort);
  }
  final parts = value.split(':');
  if (parts.length == 2) {
    final parsedPort = int.tryParse(parts[1]);
    return _HostPort(
      parts[0].isEmpty ? defaultHost : parts[0],
      parsedPort ?? defaultPort,
    );
  }
  return _HostPort(value, defaultPort);
}

Future<bool> _isEndpointReachable(_HostPort endpoint) async {
  try {
    final socket = await Socket.connect(
      endpoint.host,
      endpoint.port,
      timeout: const Duration(milliseconds: 600),
    );
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}

Future<FirebaseApp> _ensureFirebaseApp(String name) async {
  FirebaseApp defaultApp;
  if (Firebase.apps.isEmpty) {
    defaultApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    defaultApp = Firebase.apps.first;
  }

  if (name == defaultApp.name) {
    return defaultApp;
  }

  try {
    return Firebase.app(name);
  } on FirebaseException catch (error) {
    if (error.code == 'no-app') {
      return Firebase.initializeApp(
        name: name,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    rethrow;
  }
}

Future<void> _seedPublicProfile(
  _HostPort firestoreEndpoint,
  String projectId,
  String docId,
) async {
  final client = http.Client();
  final payload = jsonEncode({
    'fields': {
      'displayName': {'stringValue': 'Integration Test User'},
      'bio': {'stringValue': 'Seedlenmis test kaydi'},
      'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
    },
  });

  try {
    final authority = '${firestoreEndpoint.host}:${firestoreEndpoint.port}';
    final basePath =
        '/v1/projects/$projectId/databases/(default)/documents/public_profiles';
    final createUri = Uri.http(authority, basePath, {'documentId': docId});
    final headers = {
      'content-type': 'application/json',
      // Firestore emülatöründe admin benzeri haklar için owner token kullan.
      'Authorization': 'Bearer owner',
    };

    final createResponse = await client.post(
      createUri,
      headers: headers,
      body: payload,
    );

    if (createResponse.statusCode == 409) {
      // Doc mevcut, güncelle.
      final updateUri = Uri.http(authority, '$basePath/$docId');
      final updateResponse = await client.patch(
        updateUri,
        headers: headers,
        body: payload,
      );
      if (updateResponse.statusCode >= 400) {
        throw StateError(
          'Firestore seed patch hatasi: '
          '${updateResponse.statusCode} ${updateResponse.body}',
        );
      }
    } else if (createResponse.statusCode >= 400) {
      throw StateError(
        'Firestore seed hatasi: '
        '${createResponse.statusCode} ${createResponse.body}',
      );
    }
  } finally {
    client.close();
  }
}

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final projectId = DefaultFirebaseOptions.currentPlatform.projectId;

  final useEmulator =
      (Platform.environment['CRINGEBANK_USE_FIREBASE_EMULATOR'] ?? '')
          .toLowerCase() ==
      'true';

  final firestoreEndpoint = _resolveEndpoint(
    envValue: Platform.environment['FIRESTORE_EMULATOR_HOST'],
    defaultPort: 8080,
  );
  final authEndpoint = _resolveEndpoint(
    envValue: Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'],
    defaultPort: 9099,
  );

  var emulatorSkipMessage =
      'Firebase emülatörü devre dışı. '
      'CRINGEBANK_USE_FIREBASE_EMULATOR=true ayarlayın.';
  if (useEmulator) {
    final authReachable = await _isEndpointReachable(authEndpoint);
    final firestoreReachable = await _isEndpointReachable(firestoreEndpoint);
    if (authReachable && firestoreReachable) {
      emulatorSkipMessage = '';
    } else {
      emulatorSkipMessage =
          'Firebase emülatörüne ulaşılamıyor: auth=$authEndpoint, '
          'firestore=$firestoreEndpoint.';
    }
  }

  final bool skipEmulatorTests = emulatorSkipMessage.isNotEmpty;
  final String? emulatorSkipReason = skipEmulatorTests
      ? emulatorSkipMessage
      : null;
  if (skipEmulatorTests && emulatorSkipReason != null) {
    debugPrint('⚠️ Firebase emülatör testleri atlandı: $emulatorSkipReason');
  }

  group('Firebase Auth emülatörü', () {
    late FirebaseAuth auth;

    setUpAll(() async {
      if (skipEmulatorTests) {
        return;
      }
      final app = await _ensureFirebaseApp('integration-emulator');
      auth = FirebaseAuth.instanceFor(app: app);
      auth.useAuthEmulator(authEndpoint.host, authEndpoint.port);
      await auth.signOut();
    });

    tearDown(() async {
      if (skipEmulatorTests) {
        return;
      }
      final user = auth.currentUser;
      if (user != null) {
        await user.delete();
      }
      await auth.signOut();
    });

    testWidgets('yeni kullanıcı oluşturup giriş yapar', (tester) async {
      final email =
          'integration_${DateTime.now().millisecondsSinceEpoch}@test.dev';
      const password = 'StrongPass123!';

      final created = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      expect(created.user, isNotNull);
      expect(created.user?.email, email);

      await auth.signOut();

      final signedIn = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      expect(signedIn.user, isNotNull);
      expect(signedIn.user?.email, email);
    }, skip: skipEmulatorTests);

    testWidgets('yanlış parola hatası döner', (tester) async {
      final email =
          'integration_${DateTime.now().millisecondsSinceEpoch}@test.dev';
      const password = 'StrongPass123!';

      await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await auth.signOut();

      await expectLater(
        auth.signInWithEmailAndPassword(
          email: email,
          password: 'WrongPass321!',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            anyOf(
              equals('wrong-password'),
              equals('invalid-credential'),
              equals('INVALID_LOGIN_CREDENTIALS'),
            ),
          ),
        ),
      );
    }, skip: skipEmulatorTests);
  });

  group('Firestore emülatörü', () {
    late FirebaseFirestore firestore;

    setUpAll(() async {
      if (skipEmulatorTests) {
        return;
      }
      final app = await _ensureFirebaseApp('integration-emulator');
      firestore = FirebaseFirestore.instanceFor(app: app);
      firestore.useFirestoreEmulator(
        firestoreEndpoint.host,
        firestoreEndpoint.port,
      );
      await FirebaseAuth.instanceFor(app: app).signOut();
    });

    testWidgets('public_profiles belgesini okuyabilir', (tester) async {
      final docId =
          'integration_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';

      await _seedPublicProfile(firestoreEndpoint, projectId, docId);

      final snapshot = await firestore
          .collection('public_profiles')
          .doc(docId)
          .get();

      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), isNotNull);
      expect(snapshot.data()!['displayName'], 'Integration Test User');
    }, skip: skipEmulatorTests);

    testWidgets('korunan koleksiyona yazma erişimi reddedilir', (tester) async {
      await expectLater(
        firestore.collection('user_security').doc('anonymous').set({
          'status': 'denied',
          'createdAt': DateTime.now().toIso8601String(),
        }),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            contains('permission-denied'),
          ),
        ),
      );
    }, skip: skipEmulatorTests);
  });

  final runRemote =
      (Platform.environment['CRINGEBANK_RUN_FIREBASE_REMOTE_TESTS'] ?? '')
          .toLowerCase() ==
      'true';
  final remoteEmail = Platform.environment['CRINGEBANK_REMOTE_EMAIL'];
  final remotePassword = Platform.environment['CRINGEBANK_REMOTE_PASSWORD'];

  String remoteSkipMessage =
      'Remote Firebase testleri kapalı. '
      'CRINGEBANK_RUN_FIREBASE_REMOTE_TESTS=true ayarlayın.';
  if (runRemote) {
    if (remoteEmail != null && remotePassword != null) {
      remoteSkipMessage = '';
    } else {
      remoteSkipMessage =
          'Remote testler için CRINGEBANK_REMOTE_EMAIL ve '
          'CRINGEBANK_REMOTE_PASSWORD gerekiyor.';
    }
  }
  final bool skipRemoteTests = remoteSkipMessage.isNotEmpty;
  final String? remoteSkipReason = skipRemoteTests ? remoteSkipMessage : null;
  if (skipRemoteTests && remoteSkipReason != null) {
    debugPrint('⚠️ Remote Firebase testleri atlandı: $remoteSkipReason');
  }

  group('Firebase Auth remote', () {
    late FirebaseAuth remoteAuth;

    setUpAll(() async {
      if (skipRemoteTests) {
        return;
      }
      final app = await _ensureFirebaseApp('integration-remote');
      remoteAuth = FirebaseAuth.instanceFor(app: app);
      await remoteAuth.signOut();
    });

    tearDown(() async {
      if (skipRemoteTests) {
        return;
      }
      await remoteAuth.signOut();
    });

    testWidgets('geçerli kimlik bilgileri giriş yapar', (tester) async {
      final credential = await remoteAuth.signInWithEmailAndPassword(
        email: remoteEmail!,
        password: remotePassword!,
      );
      expect(credential.user, isNotNull);
      expect(credential.user?.email, remoteEmail);
    }, skip: skipRemoteTests);

    testWidgets('yanlış şifre hatası döner', (tester) async {
      await expectLater(
        remoteAuth.signInWithEmailAndPassword(
          email: remoteEmail!,
          password: '${remotePassword!}_wrong',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            anyOf(
              equals('wrong-password'),
              equals('invalid-credential'),
              equals('INVALID_LOGIN_CREDENTIALS'),
            ),
          ),
        ),
      );
    }, skip: skipRemoteTests);
  });
}
