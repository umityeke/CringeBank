// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:cringe_bankasi/main.dart';

void main() {
  // Production pipeline does not provision Firebase emulators; keep the smoke test skipped.
  testWidgets('Cringe Bankası app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CringeBankApp());

    // Verify that our app loads with login screen
    expect(find.text('CRINGE BANKASI'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  }, skip: true);
}
