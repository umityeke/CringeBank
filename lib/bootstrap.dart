import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/advanced_ai_service.dart';
import 'services/competition_service.dart';
import 'services/cringe_entry_service.dart';
import 'services/cringe_notification_service.dart';
import 'services/cringe_search_service.dart';
import 'services/user_service.dart';

Future<void> bootstrap(Widget app) async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    _configureLogging();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await _configureFirestore();

    AdvancedAIService.initialize();

    await Future.wait([
      CringeNotificationService.initialize(),
      CringeSearchService.initialize(),
    ]);

    await UserService.instance.initialize();
    _setupPostAuthInitializers();

    await FirebaseFirestore.instance.waitForPendingWrites();

    runApp(app);
  }, _logSevereError);
}

void _configureLogging() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logSevereError(details.exception, details.stack ?? StackTrace.current);
  };
}

Future<void> _configureFirestore() async {
  final firestore = FirebaseFirestore.instance;

  try {
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024,
    );
  } catch (error, stackTrace) {
    _logSevereError(error, stackTrace);
  }
}

void _setupPostAuthInitializers() {
  firebase_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      unawaited(CompetitionService.initialize());
      unawaited(CringeEntryService.instance.warmUp());
    } else {
      CompetitionService.dispose();
    }
  });
}

void _logSevereError(Object error, StackTrace stackTrace) {
  debugPrint('🔥 Unhandled exception: $error');
  debugPrint(stackTrace.toString());
}
