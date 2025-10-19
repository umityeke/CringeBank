import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cringebank/core/session/session_controller.dart';
import 'package:cringebank/core/session/session_local_storage.dart';

void main() {
  group('SessionController', () {
    late SessionController controller;
    late SharedPreferencesSessionLocalStorage storage;
    late DateTime now;

    setUp(() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      now = DateTime(2025, 10, 19, 12);
      storage = SharedPreferencesSessionLocalStorage(prefs);
      controller = SessionController(
        storage: storage,
        now: () => now,
        defaultTtl: const Duration(hours: 1),
      );
    });

    test('updateExpiry extends persisted expiry', () async {
      await controller.setAuthenticated(
        identifier: 'user-123',
        authenticatedAt: now,
        ttl: const Duration(hours: 2),
      );

      final newExpiry = now.add(const Duration(hours: 4));
      await controller.updateExpiry(newExpiry);

      expect(controller.state.expiresAt, newExpiry);
      final persisted = await storage.load();
      expect(persisted?.expiresAt, newExpiry);
    });

    test('updateExpiry ignored when not authenticated', () async {
      final newExpiry = now.add(const Duration(hours: 4));
      await controller.updateExpiry(newExpiry);

      expect(controller.state.expiresAt, isNull);
      final persisted = await storage.load();
      expect(persisted, isNull);
    });
  });
}
