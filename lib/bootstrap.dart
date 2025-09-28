import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'services/advanced_ai_service.dart';
import 'services/competition_service.dart';
import 'services/cringe_entry_service.dart';
import 'services/cringe_notification_service.dart';
import 'services/cringe_search_service.dart';
import 'services/user_service.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
bool _crashlyticsEnabled = false;

bool get _hasSentry => _sentryDsn.isNotEmpty;

Future<void> bootstrap(Widget app) async {
  if (_hasSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.enableAutoSessionTracking = true;
      },
      appRunner: () async => _runAppWithGuards(app),
    );
  } else {
    await _runAppWithGuards(app);
  }
}

void _configureLogging() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

Future<void> _runAppWithGuards(Widget app) async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    _configureLogging();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await _configureCrashReporting();
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
  unawaited(_recordFatalError(error, stackTrace));
}

Future<void> _configureCrashReporting() async {
  if (kIsWeb) {
    debugPrint('Crashlytics is not supported on web platforms.');
    return;
  }

  try {
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    _crashlyticsEnabled = true;
  } catch (error, stackTrace) {
    debugPrint('Crashlytics initialization failed: $error');
    _crashlyticsEnabled = false;
    _logSevereError(error, stackTrace);
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      _recordFatalError(details.exception, details.stack ?? StackTrace.current),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _logSevereError(error, stack);
    return true;
  };
}

Future<void> _recordFatalError(Object error, StackTrace stackTrace) async {
  if (_crashlyticsEnabled) {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: true,
    );
  }

  if (_hasSentry) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}
