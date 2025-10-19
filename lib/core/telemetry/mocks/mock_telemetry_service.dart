import '../telemetry_service.dart';

class MockTelemetryService implements TelemetryService {
  MockTelemetryService();

  final List<TelemetryEvent> events = [];

  @override
  Future<void> record(TelemetryEvent event) async {
    events.add(event);
  }

  void reset() {
    events.clear();
  }
}
