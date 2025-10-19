import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cringebank/core/telemetry/telemetry_providers.dart';

import 'registration_controller.dart';

final registrationControllerProvider =
    StateNotifierProvider<RegistrationController, RegistrationFlowState>((ref) {
  final telemetry = ref.watch(telemetryServiceProvider);
  return RegistrationController(telemetry: telemetry);
});

final registrationRestorationProvider = FutureProvider<void>((ref) async {
  await ref.read(registrationControllerProvider.notifier).initialize();
});

final registrationRequiredProvider = Provider<bool>((ref) {
  final state = ref.watch(registrationControllerProvider);
  return state.requiresRegistration;
});
