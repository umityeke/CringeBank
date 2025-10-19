import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_local_storage.dart';
import 'session_remote_repository.dart';
import 'session_state.dart';
import '../telemetry/telemetry_service.dart';
import '../telemetry/telemetry_utils.dart';

class SessionController extends StateNotifier<SessionState> {
  SessionController({
    SessionLocalStorage? storage,
    DateTime Function()? now,
    Duration? defaultTtl,
    SessionRemoteRepository? remote,
    TelemetryService? telemetry,
  })  : _storage = storage,
        _now = now ?? DateTime.now,
        _defaultTtl = defaultTtl ?? const Duration(hours: 12),
        _remote = remote,
        _telemetry = telemetry,
        super(SessionState.initial());

  final SessionLocalStorage? _storage;
  final DateTime Function() _now;
  final Duration _defaultTtl;
  final SessionRemoteRepository? _remote;
  final TelemetryService? _telemetry;

  Future<void> hydrate() async {
    final storage = _storage;
    if (storage == null) {
      state = state.copyWith(isHydrated: true);
      return;
    }
    final persisted = await storage.load();
    if (persisted == null) {
      state = state.copyWith(isHydrated: true);
      return;
    }
    final now = _now();
    if (persisted.expiresAt.isBefore(now)) {
      await storage.clear();
      state = state.copyWith(isHydrated: true);
      return;
    }
    state = state.copyWith(
      isHydrated: true,
      isAuthenticated: persisted.isAuthenticated,
      identifier: persisted.identifier,
      displayName: persisted.displayName,
      expiresAt: persisted.expiresAt,
      requiresDeviceVerification: false,
    );
  }

  Future<void> setAuthenticated({
    required String identifier,
    String? displayName,
    DateTime? authenticatedAt,
    Duration? ttl,
    SessionLoginContext? loginContext,
  }) async {
    final issuedAt = authenticatedAt ?? _now();
    final expiresAt = issuedAt.add(ttl ?? _defaultTtl);
    var requiresDeviceVerification = false;
    final remote = _remote;
    if (remote != null && loginContext != null) {
      final outcome = await remote.registerDeviceLogin(
        identifier: identifier,
        context: loginContext,
      );
      requiresDeviceVerification = outcome.requiresDeviceVerification;
    }
    state = state.copyWith(
      isHydrated: true,
      isAuthenticated: true,
      identifier: identifier,
      displayName: displayName,
      expiresAt: expiresAt,
      requiresDeviceVerification: requiresDeviceVerification,
    );
    await _storage?.save(
      isAuthenticated: true,
      identifier: identifier,
      displayName: displayName,
      expiresAt: expiresAt,
    );
  }

  Future<void> reset() async {
    state = SessionState.initial().copyWith(isHydrated: true);
    await _storage?.clear();
  }

  Future<void> updateExpiry(DateTime newExpiresAt) async {
    if (!state.isAuthenticated) {
      return;
    }
    state = state.copyWith(expiresAt: newExpiresAt);
    await _storage?.save(
      isAuthenticated: true,
      identifier: state.identifier,
      displayName: state.displayName,
      expiresAt: newExpiresAt,
    );
  }

  Future<bool> expireIfNeeded() async {
    final expiresAt = state.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    if (expiresAt.isAfter(_now())) {
      return false;
    }
    await reset();
    return true;
  }

  Future<void> revokeAllSessions({bool includeCurrentDevice = true}) async {
    final identifier = state.identifier;
    if (identifier == null) {
      return;
    }
    await _remote?.revokeAllSessions(identifier: identifier);
    _emitSessionRevoked(
      identifier: identifier,
      includeCurrentDevice: includeCurrentDevice,
      remoteNotified: _remote != null,
    );
    if (includeCurrentDevice) {
      await reset();
    }
  }

  void _emitSessionRevoked({
    required String identifier,
    required bool includeCurrentDevice,
    required bool remoteNotified,
  }) {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return;
    }
    final hashedIdentifier = hashIdentifier(identifier);
    unawaited(
      telemetry.record(
        TelemetryEvent(
          name: TelemetryEventName.sessionRevoked,
          timestamp: _now(),
          attributes: {
            'identifierHash': hashedIdentifier,
            'includeCurrentDevice': includeCurrentDevice,
            'remoteNotified': remoteNotified,
          },
        ),
      ),
    );
  }
}
