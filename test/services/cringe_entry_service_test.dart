import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cringe_bankasi/models/cringe_entry.dart';
import 'package:cringe_bankasi/services/cringe_entry_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CringeEntryService service;
  late FirebaseFirestore mockFirestore;
  late firebase_auth.FirebaseAuth mockAuth;
  late FirebaseStorage mockStorage;
  late FirebaseAnalytics mockAnalytics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockFirestore = _MockFirebaseFirestore();
    mockAuth = _MockFirebaseAuth();
    mockStorage = _MockFirebaseStorage();
    mockAnalytics = _MockFirebaseAnalytics();

    CringeEntryService.configureForTesting(
      firestore: mockFirestore,
      auth: mockAuth,
      storage: mockStorage,
      analytics: mockAnalytics,
    );

    service = CringeEntryService.instance;
  });

  tearDown(() {
    CringeEntryService.resetForTesting();
  });

  test('cache returns entries when TTL is valid', () async {
    final entry = CringeEntry.mockBasic();

    await service.primeCacheForTesting([entry]);
    final cachedEntries = await service.getCachedEntriesForTesting();

    expect(cachedEntries, isNotEmpty);
    expect(cachedEntries.first.id, entry.id);
  });

  test('cache invalidates entries when TTL expires', () async {
    final entry = CringeEntry.mockBasic();
    final serialized = jsonEncode([entry.toJson()]);
    final expiredTimestamp = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 10))
        .millisecondsSinceEpoch;

    SharedPreferences.setMockInitialValues({
      'enterprise_cringe_entries_cache_v1': serialized,
      'enterprise_cringe_entries_cache_timestamp_v1': expiredTimestamp,
    });

    final cachedEntries = await service.getCachedEntriesForTesting();

    expect(cachedEntries, isEmpty);
  });
}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class _MockFirebaseStorage extends Mock implements FirebaseStorage {}

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}
