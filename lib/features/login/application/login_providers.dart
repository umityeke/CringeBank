import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/config/super_admin_security_policy.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/device_fingerprint_state.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/telemetry/telemetry_providers.dart';
import '../domain/models/login_models.dart';
import '../domain/services/login_service.dart';
import 'login_controller.dart';
import '../data/login_local_storage.dart';
import '../data/login_audit_service.dart';

final loginServiceProvider = Provider<LoginService>((ref) {
  return sl<LoginService>();
});

final loginLocalStorageProvider = Provider<LoginLocalStorage>((ref) {
  return sl<LoginLocalStorage>();
});

final loginAuditServiceProvider = Provider<LoginAuditService>((ref) {
  return sl<LoginAuditService>();
});

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>((ref) {
  final service = ref.watch(loginServiceProvider);
  final sessionController = ref.watch(sessionControllerProvider.notifier);
  final storage = ref.watch(loginLocalStorageProvider);
  final telemetry = ref.watch(telemetryServiceProvider);
  final featureFlags = ref.watch(featureFlagsProvider);
  final superAdminPolicy = ref.watch(superAdminSecurityPolicyProvider);
  final sessionRefreshCoordinator =
      ref.watch(sessionRefreshCoordinatorProvider);
  final fingerprintController =
    ref.read(deviceFingerprintControllerProvider.notifier);
  final fingerprintState = ref.read(deviceFingerprintControllerProvider);
  final loginAuditService = ref.watch(loginAuditServiceProvider);
  final deviceIdHash = fingerprintState.deviceIdHash.isNotEmpty
    ? fingerprintState.deviceIdHash
    : 'mock-device';
  final deviceInfo = DeviceInfo(
    deviceIdHash: deviceIdHash,
    isTrusted: fingerprintState.isTrusted,
  );
  final controller = LoginController(
    service,
    sessionController: sessionController,
    loginStorage: storage,
    telemetry: telemetry,
    featureFlags: featureFlags,
    superAdminPolicy: superAdminPolicy,
    sessionRefreshCoordinator: sessionRefreshCoordinator,
    deviceInfo: deviceInfo,
    deviceFingerprintController: fingerprintController,
    loginAuditService: loginAuditService,
  );
  ref.listen<DeviceFingerprintState>(
    deviceFingerprintControllerProvider,
    (previous, next) {
      final nextId = next.deviceIdHash.isNotEmpty
          ? next.deviceIdHash
          : controller.deviceIdHash;
      controller.setDeviceInfo(
        deviceIdHash: nextId,
        isTrusted: next.isTrusted,
      );
    },
  );
  unawaited(controller.hydrate());
  return controller;
});

final loginAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(sessionAuthProvider);
});
