import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cringebank/core/telemetry/telemetry_service.dart';
import 'package:cringebank/core/telemetry/telemetry_providers.dart';
import 'package:cringebank/features/profile/application/tag_approval_providers.dart';
import 'package:cringebank/features/profile/data/repositories/mock_tag_approval_repository.dart';
import 'package:cringebank/features/profile/presentation/widgets/tag_approval_panel.dart';

class _FakeTelemetryService implements TelemetryService {
  final List<TelemetryEvent> events = [];

  @override
  Future<void> record(TelemetryEvent event) async {
    events.add(event);
  }
}

void main() {
  late MockTagApprovalRepository repository;
  late _FakeTelemetryService telemetry;

  setUp(() {
    repository = MockTagApprovalRepository();
    telemetry = _FakeTelemetryService();
  });

  tearDown(() async {
    await repository.dispose();
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagApprovalRepositoryProvider.overrideWithValue(repository),
          telemetryServiceProvider.overrideWithValue(telemetry),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: TagApprovalPanel(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('pending girişler listelenir ve onaylanınca kaldırılır', (tester) async {
  await pumpPanel(tester);
    expect(find.text('Kerem S.'), findsOneWidget);
    expect(find.text('Lina V.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tagApprovalApprove_tag-1001')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Kerem S.'), findsNothing);
    expect(telemetry.events.where((e) => e.name == TelemetryEventName.tagApprovalDecision), isNotEmpty);
  });

  testWidgets('onaylama kapatılınca mesaj gösterilir ve telemetri yazılır', (tester) async {
  await pumpPanel(tester);

    await tester.tap(find.byKey(const Key('tagApprovalToggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Onay kuyruğu kapalı. Etiketler otomatik olarak profilinde yayınlanır.'),
      findsOneWidget,
    );

    final preferenceEvents = telemetry.events
        .where((event) => event.name == TelemetryEventName.tagApprovalPreferenceChanged)
        .toList();
    expect(preferenceEvents, hasLength(2));
    expect(preferenceEvents.last.attributes['status'], 'success');
  });
}
