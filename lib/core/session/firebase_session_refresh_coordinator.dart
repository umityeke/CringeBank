import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import 'session_bootstrap.dart';
import 'session_controller.dart';
import 'session_refresh_service.dart';

/// Coordinates Firebase ID token refresh cycles to keep the local session data
/// in sync with backend TTL requirements. The coordinator refreshes the token
/// shortly before expiry, retries with a backoff strategy on failure and updates
/// the [SessionController] with the renewed expiration timestamp so navigation
/// guards keep working without forcing the user to re-login.
class FirebaseSessionRefreshCoordinator extends SessionRefreshCoordinator {
  FirebaseSessionRefreshCoordinator({
    SessionController? sessionController,
    firebase_auth.FirebaseAuth? auth,
    DateTime Function()? now,
    Duration preemptiveRefreshWindow = const Duration(minutes: 5),
    Duration minRefreshInterval = const Duration(minutes: 1),
    Duration refreshRetryBackoff = const Duration(seconds: 30),
  })  : _sessionController = sessionController,
        _authInstance = auth,
        _now = now ?? DateTime.now,
        _preemptiveRefreshWindow = preemptiveRefreshWindow,
        _minRefreshInterval = minRefreshInterval,
        _refreshRetryBackoff = refreshRetryBackoff;

  static const Duration _fallbackSessionDuration = Duration(hours: 12);

  final SessionController? _sessionController;
  firebase_auth.FirebaseAuth? _authInstance;
  final DateTime Function() _now;
  final Duration _preemptiveRefreshWindow;
  final Duration _minRefreshInterval;
  final Duration _refreshRetryBackoff;

  Timer? _refreshTimer;
  Timer? _retryTimer;
  SessionBootstrapData? _currentSession;
  Duration? _sessionDuration;
  bool _isRefreshing = false;
  bool _pendingForcedRefresh = false;
  bool _isDisposed = false;
  DateTime? _lastRefreshAttempt;

  firebase_auth.FirebaseAuth? get _auth {
    if (_authInstance != null) {
      return _authInstance;
    }
    try {
      _authInstance = firebase_auth.FirebaseAuth.instance;
    } catch (error, stackTrace) {
      debugPrint('Session refresh auth unavailable: $error');
      debugPrint('$stackTrace');
      return null;
    }
    return _authInstance;
  }

  @override
  void registerSession({
    required String identifier,
    required SessionBootstrapData session,
  }) {
    if (_isDisposed) {
      return;
    }

    _cancelTimers();
    _currentSession = session;
    _sessionDuration = _deriveSessionDuration(session);

    final now = _now();
    final timeUntilExpiry = session.expiresAt.difference(now);
    if (timeUntilExpiry <= _preemptiveRefreshWindow) {
      unawaited(_refreshToken(forced: true));
      return;
    }

    _scheduleRefresh();
  }

  @override
  Future<void> forceRefresh() {
    if (_isDisposed) {
      return Future.value();
    }
    return _refreshToken(forced: true);
  }

  @override
  void clear() {
    _cancelTimers();
    _currentSession = null;
    _sessionDuration = null;
    _pendingForcedRefresh = false;
    _isRefreshing = false;
    _lastRefreshAttempt = null;
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    clear();
  }

  Duration _deriveSessionDuration(SessionBootstrapData session) {
    final duration = session.expiresAt.difference(session.issuedAt);
    if (duration.isNegative || duration.inSeconds == 0) {
      return _fallbackSessionDuration;
    }
    return duration;
  }

  void _scheduleRefresh() {
    final session = _currentSession;
    if (session == null || _isDisposed) {
      return;
    }
    final now = _now();
    var refreshAt = session.expiresAt.subtract(_preemptiveRefreshWindow);
    final minimumAllowed = now.add(_minRefreshInterval);
    if (refreshAt.isBefore(minimumAllowed)) {
      refreshAt = minimumAllowed;
    }
    final delay = refreshAt.difference(now);
    _refreshTimer = Timer(delay, () {
      unawaited(_refreshToken(forced: false));
    });
  }

  void _scheduleRetry() {
    if (_isDisposed) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = Timer(_refreshRetryBackoff, () {
      _retryTimer = null;
      unawaited(_refreshToken(forced: true));
    });
  }

  void _cancelTimers() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> _refreshToken({required bool forced}) async {
    if (_isDisposed) {
      return;
    }
    if (_isRefreshing) {
      if (forced) {
        _pendingForcedRefresh = true;
      }
      return;
    }
    final session = _currentSession;
    if (session == null) {
      return;
    }

    final now = _now();
    if (!forced && _lastRefreshAttempt != null) {
      final sinceLast = now.difference(_lastRefreshAttempt!);
      if (sinceLast < _minRefreshInterval) {
        _scheduleRefresh();
        return;
      }
    }

    _isRefreshing = true;
    _lastRefreshAttempt = now;

    try {
      final auth = _auth;
      final user = auth?.currentUser;
      if (auth == null || user == null) {
        debugPrint('Session refresh skipped: missing Firebase user');
        clear();
        return;
      }

      final tokenResult = await user.getIdTokenResult(true);
      final issuedAtUtc = tokenResult.issuedAtTime?.toUtc() ?? now.toUtc();
      final newIssuedAt = issuedAtUtc.toLocal();

      var effectiveDuration = _sessionDuration ?? _fallbackSessionDuration;
      final firebaseExpirationUtc = tokenResult.expirationTime?.toUtc();
      DateTime newExpiresAt;
      if (firebaseExpirationUtc != null) {
        newExpiresAt = firebaseExpirationUtc.toLocal();
        final refreshedDuration = newExpiresAt.difference(newIssuedAt);
        if (!refreshedDuration.isNegative && refreshedDuration.inSeconds > 0) {
          effectiveDuration = refreshedDuration;
        }
      } else {
        newExpiresAt = newIssuedAt.add(effectiveDuration);
      }
      _sessionDuration = effectiveDuration;

      final controller = _sessionController;
      if (controller != null) {
        await controller.updateExpiry(newExpiresAt);
      }

      _currentSession = session.copyWith(
        issuedAt: newIssuedAt,
        expiresAt: newExpiresAt,
      );

      _scheduleRefresh();
    } catch (error, stackTrace) {
      debugPrint('Session refresh failed: $error');
      debugPrint('$stackTrace');
      _scheduleRetry();
    } finally {
      _isRefreshing = false;
      if (_pendingForcedRefresh && !_isDisposed) {
        _pendingForcedRefresh = false;
        unawaited(_refreshToken(forced: true));
      }
    }
  }
}
