import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/service_locator.dart';
import 'telemetry_service.dart';

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return sl<TelemetryService>();
});
