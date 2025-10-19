import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cringebank/core/session/session_controller.dart';
import 'package:cringebank/core/session/session_providers.dart';
import 'package:cringebank/core/telemetry/mocks/mock_telemetry_service.dart';
import 'package:cringebank/core/telemetry/telemetry_providers.dart';
import 'package:cringebank/features/feed/application/feed_providers.dart';
import 'package:cringebank/features/feed/domain/models/feed_entry.dart';
import 'package:cringebank/features/feed/domain/models/feed_segment.dart';
import 'package:cringebank/features/feed/domain/models/sponsor_campaign.dart';
import 'package:cringebank/features/feed/domain/repositories/feed_repository.dart';
import 'package:cringebank/features/feed/presentation/pages/feed_page.dart';

class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository({
    required this.entries,
    required this.campaigns,
  });

  final Stream<List<FeedEntry>> entries;
  final Stream<List<SponsorCampaign>> campaigns;

  @override
  Stream<List<FeedEntry>> watchEntries({
    required FeedSegment segment,
    required String userId,
  }) {
    return entries;
  }

  @override
  Stream<List<SponsorCampaign>> watchSponsorCampaigns({
    required String userId,
  }) {
    return campaigns;
  }

  @override
  Future<void> refreshRecommended({required String userId}) async {
    return;
  }
}

Future<void> _pumpFeed(
  WidgetTester tester,
  FeedRepository repository,
) async {
  final session = SessionController();
  session.state = session.state.copyWith(
    isHydrated: true,
    isAuthenticated: true,
    identifier: 'user-123',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith((ref) => session),
        telemetryServiceProvider.overrideWithValue(MockTelemetryService()),
        feedRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: FeedPage()),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedPage', () {
    testWidgets('veri geldiğinde entries listelenir', (tester) async {
      const entry = FeedEntry(
        id: 'entry-1',
        author: 'Cringe Master',
        title: 'Yeni cringe paylaşımı',
        excerpt: 'Bugün gördüğüm en feci cringe.',
        relativeTime: '5 dk',
        tag: 'trend',
        likeCount: 12,
        commentCount: 3,
        accentColor: Colors.purple,
        rankingReasons: <String>['recent'],
        rankingStrategy: 'hybrid',
      );

      final repository = _FakeFeedRepository(
        entries: Stream<List<FeedEntry>>.value(const [entry]),
        campaigns: Stream<List<SponsorCampaign>>.value(const <SponsorCampaign>[]),
      );

      await _pumpFeed(tester, repository);

      expect(find.text('Takip Ettiklerin'), findsOneWidget);
      expect(find.text('Yeni cringe paylaşımı'), findsOneWidget);
      expect(find.textContaining('Sıralama modu'), findsOneWidget);
    });

    testWidgets('akış hata aldığında uyarı gösterilir', (tester) async {
      final repository = _FakeFeedRepository(
        entries: Stream<List<FeedEntry>>.error(Exception('network error')),
        campaigns: Stream<List<SponsorCampaign>>.value(const <SponsorCampaign>[]),
      );

      await _pumpFeed(tester, repository);

      expect(
        find.text('Akış yüklenirken sorun oluştu.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('network error'),
        findsOneWidget,
      );
    });
  });
}
