import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/service_locator.dart';
import 'device_fingerprint_controller.dart';
import 'device_fingerprint_state.dart';
import 'session_controller.dart';
import 'session_state.dart';
import 'session_refresh_service.dart';

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  final controller = sl<SessionController>();
  unawaited(controller.hydrate());
  return controller;
});

final sessionAuthProvider = Provider<bool>((ref) {
  final state = ref.watch(sessionControllerProvider);
  return state.isAuthenticated;
});

final sessionHydratedProvider = Provider<bool>((ref) {
  final state = ref.watch(sessionControllerProvider);
  return state.isHydrated;
});

final sessionRefreshCoordinatorProvider =
    Provider<SessionRefreshCoordinator>((ref) {
  return sl<SessionRefreshCoordinator>();
});

final deviceFingerprintControllerProvider =
    StateNotifierProvider<DeviceFingerprintController, DeviceFingerprintState>(
        (ref) {
  final controller = sl<DeviceFingerprintController>();
  unawaited(controller.hydrate());
  return controller;
});
