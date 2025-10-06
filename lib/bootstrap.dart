import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'services/advanced_ai_service.dart';
import 'services/cringe_entry_service.dart';
import 'services/cringe_search_service.dart';
import 'services/user_service.dart';
import 'services/crash_reporting/crash_reporting_service_factory.dart';
import 'services/crash_reporting/i_crash_reporting_service.dart';
import 'services/notifications/notification_service_factory.dart';
import 'services/notifications/i_notification_service.dart';

const String _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);

// Platform-aware services - created once during bootstrap
late final ICrashReportingService _crashReportingService;
late final INotificationService _notificationService;

bool get _hasSentry => _sentryDsn.isNotEmpty;

Future<void> bootstrap(Widget app) async {
  if (_hasSentry) {
    await SentryFlutter.init((options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.enableAutoSessionTracking = true;
    }, appRunner: () async => _runAppWithGuards(app));
  } else {
    await _runAppWithGuards(app);
  }
}

void _configureLogging() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

void _configureErrorHandlers() {
  // Configure Flutter error handler
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      _recordFatalError(details.exception, details.stack ?? StackTrace.current),
    );
  };

  // Configure platform dispatcher error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    _logSevereError(error, stack);
    return true;
  };
}

Future<void> _runAppWithGuards(Widget app) async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    _configureLogging();

    // Initialize Firebase (safely handles platforms where it's not available)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Create platform-aware services
    _crashReportingService = CrashReportingServiceFactory.create();
    _notificationService = NotificationServiceFactory.create();

    // Initialize services
    await _crashReportingService.initialize();
    _configureErrorHandlers();
    await _configureFirestore();

    AdvancedAIService.initialize();

    await Future.wait([
      _notificationService.initialize(),
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
      unawaited(CringeEntryService.instance.warmUp());
    }
  });
}

void _logSevereError(Object error, StackTrace stackTrace) {
  debugPrint('ğ” Unhandled exception: $error');
  debugPrint(stackTrace.toString());
  unawaited(_recordFatalError(error, stackTrace));
}

Future<void> _recordFatalError(Object error, StackTrace stackTrace) async {
  // Record error using platform-aware crash reporting service
  await _crashReportingService.recordFatalError(
    error,
    stackTrace,
    reason: 'Unhandled exception',
  );

  // Also send to Sentry if configured
  if (_hasSentry) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}
