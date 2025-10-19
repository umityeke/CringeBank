import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cringebank/features/feed/application/feed_ranking_service.dart';
import 'package:cringebank/features/feed/domain/models/feed_entry.dart';
import 'package:cringebank/features/feed/domain/models/feed_segment.dart';

void main() {
  group('FeedRankingService sponsor frekans kısıtları', () {
    FeedEntry buildEntry({
      required String id,
      required double baseScore,
      String tag = 'genel',
    }) {
      return FeedEntry(
        id: id,
        author: 'Yazar $id',
        title: 'Başlık $id',
        excerpt: 'Özet',
        relativeTime: 'az önce',
        tag: tag,
        likeCount: 0,
        commentCount: 0,
        accentColor: Colors.blue,
        baseScore: baseScore,
      );
    }

    test('Sponsor içerikler en az dört organik öğe aralığıyla gösterilir', () {
      final service = FeedRankingService(now: () => DateTime(2025, 10, 19));
      final entries = <FeedEntry>[
        buildEntry(id: 's1', baseScore: 9, tag: 'sponsor'),
        buildEntry(id: 'o1', baseScore: 8),
        buildEntry(id: 'o2', baseScore: 7),
        buildEntry(id: 'o3', baseScore: 6),
        buildEntry(id: 'o4', baseScore: 5),
        buildEntry(id: 's2', baseScore: 4, tag: 'sponsor'),
        buildEntry(id: 'o5', baseScore: 3),
        buildEntry(id: 'o6', baseScore: 2),
        buildEntry(id: 's3', baseScore: 1, tag: 'sponsor'),
      ];

      final ranked = service.applyRanking(
        entries,
        segment: FeedSegment.following,
      );
      final sponsorPositions = <int>[];
      for (var i = 0; i < ranked.length; i++) {
        if (ranked[i].tag.toLowerCase() == 'sponsor') {
          sponsorPositions.add(i);
        }
      }

      expect(sponsorPositions, isNotEmpty);
      for (var i = 1; i < sponsorPositions.length; i++) {
        final gap = sponsorPositions[i] - sponsorPositions[i - 1] - 1;
        expect(
          gap >= 4,
          isTrue,
          reason: 'Sponsor öğeleri arasında en az 4 organik kart olmalı',
        );
      }

      final sponsorReasons = ranked
          .where((entry) => entry.tag.toLowerCase() == 'sponsor')
          .map((entry) => entry.rankingReasons)
          .expand((reasons) => reasons)
          .toList();
      expect(sponsorReasons, contains('sponsor:pacing'));
    });

    test('Yalnızca sponsor içerik gelirse tek kart gösterilir', () {
      final service = FeedRankingService(now: () => DateTime(2025, 10, 19));
      final entries = <FeedEntry>[
        buildEntry(id: 's1', baseScore: 3, tag: 'sponsor'),
        buildEntry(id: 's2', baseScore: 2, tag: 'sponsor'),
        buildEntry(id: 's3', baseScore: 1, tag: 'sponsor'),
      ];

      final ranked = service.applyRanking(
        entries,
        segment: FeedSegment.following,
      );

      expect(ranked.length, 1);
      expect(ranked.first.tag.toLowerCase(), 'sponsor');
      expect(ranked.first.rankingReasons, contains('sponsor:fallback'));
    });
  });
}
