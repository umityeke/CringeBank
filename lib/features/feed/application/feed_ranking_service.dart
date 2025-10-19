import 'dart:collection';
import 'dart:math';

import '../domain/models/feed_entry.dart';
import '../domain/models/feed_segment.dart';

/// Basit ranking ve çeşitlilik kuralları uygulayan yardımcı servis.
class FeedRankingService {
  FeedRankingService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Random _random = Random();

  /// Girilen feed listesini skorlayarak sıralar ve çeşitlilik limitleri uygular.
  List<FeedEntry> applyRanking(
    List<FeedEntry> entries, {
    required FeedSegment segment,
  }) {
    if (entries.isEmpty) {
      return entries;
    }

    final unique = _deduplicate(entries);
    final scored =
        unique
            .map((entry) => _scoreEntry(entry, segment))
            .toList(growable: false)
          ..sort(_sortByScoreDesc);

    final ranked = _applyDiversity(scored, segment);
    final paced = _applySponsorFrequency(ranked);
    return paced;
  }

  List<FeedEntry> _deduplicate(List<FeedEntry> entries) {
    final map = <String, FeedEntry>{};
    for (final entry in entries) {
      map[entry.id] = entry;
    }
    return map.values.toList(growable: false);
  }

  FeedEntry _scoreEntry(FeedEntry entry, FeedSegment segment) {
    final reasons = <String>[];
    final base = entry.baseScore ?? 0;
    var score = base;
    if (entry.baseScore != null) {
      reasons.add('model:${entry.baseScore!.toStringAsFixed(2)}');
    }

    final affinity = entry.affinityScore ?? 0;
    if (affinity > 0) {
      score += affinity;
      reasons.add('aff:${affinity.toStringAsFixed(2)}');
    }

    final freshnessSignal =
        entry.freshnessScore ?? _computeRecencyBoost(entry.publishedAt);
    if (freshnessSignal > 0) {
      score += freshnessSignal;
      reasons.add('fresh:${freshnessSignal.toStringAsFixed(2)}');
    }

    final diversity = entry.diversityWeight ?? 1;
    if (diversity != 1) {
      score *= diversity;
      reasons.add('div:${diversity.toStringAsFixed(2)}');
    }

    if (entry.likeCount > 0) {
      final social = log(entry.likeCount + 1) / log(10);
      score += social;
      reasons.add('eng:${social.toStringAsFixed(2)}');
    }

    final jitter = _random.nextDouble() * 0.01;
    score += jitter;

    return entry.copyWith(
      computedScore: double.parse(score.toStringAsFixed(6)),
      rankingReasons: {
        ...entry.rankingReasons,
        ...reasons,
      }.toList(growable: false),
      rankingStrategy: entry.rankingStrategy ?? segment.name,
    );
  }

  int _sortByScoreDesc(FeedEntry a, FeedEntry b) {
    final scoreA = a.computedScore ?? 0;
    final scoreB = b.computedScore ?? 0;
    if (scoreA == scoreB) {
      return a.id.compareTo(b.id);
    }
    return scoreB.compareTo(scoreA);
  }

  List<FeedEntry> _applyDiversity(
    List<FeedEntry> entries,
    FeedSegment segment,
  ) {
    final authorLimit = segment == FeedSegment.following ? 3 : 2;
    final tagLimit = segment == FeedSegment.recommended ? 2 : 3;
    final authorCounts = <String, int>{};
    final tagCounts = <String, int>{};
    final pickedIds = <String>{};
    final ranked = <FeedEntry>[];

    for (final entry in entries) {
      final author = entry.author.trim().isEmpty
          ? 'unknown'
          : entry.author.trim();
      final tag = entry.tag.trim().isEmpty
          ? 'diğer'
          : entry.tag.trim().toLowerCase();

      final authorCount = authorCounts.putIfAbsent(author, () => 0);
      final tagCount = tagCounts.putIfAbsent(tag, () => 0);

      final maxAuthor = authorLimit;
      final maxTag = tagLimit;

      if (authorCount >= maxAuthor || tagCount >= maxTag) {
        continue;
      }

      authorCounts[author] = authorCount + 1;
      tagCounts[tag] = tagCount + 1;
      pickedIds.add(entry.id);
      ranked.add(entry);
    }

    if (ranked.length >= entries.length || ranked.length >= 12) {
      return ranked;
    }

    for (final entry in entries) {
      if (pickedIds.contains(entry.id)) {
        continue;
      }
      ranked.add(
        entry.copyWith(
          rankingReasons: {
            ...entry.rankingReasons,
            'fill',
          }.toList(growable: false),
        ),
      );
      pickedIds.add(entry.id);
      if (ranked.length >= entries.length) {
        break;
      }
    }

    return ranked;
  }

  List<FeedEntry> _applySponsorFrequency(List<FeedEntry> entries) {
    if (entries.isEmpty) {
      return entries;
    }

    const minOrganicGap = 4;
    final paced = <FeedEntry>[];
    final waitingSponsors = Queue<FeedEntry>();
    var organicSinceLastSponsor = 0;

    FeedEntry markSponsor(FeedEntry entry, {bool fallback = false}) {
      final reasons = {
        ...entry.rankingReasons,
        fallback ? 'sponsor:fallback' : 'sponsor:pacing',
      };
      return entry.copyWith(rankingReasons: reasons.toList(growable: false));
    }

    bool isSponsor(FeedEntry entry) {
      final tag = entry.tag.trim().toLowerCase();
      return tag == 'sponsor' || tag == 'sponsored' || tag == 'reklam';
    }

    for (final entry in entries) {
      if (isSponsor(entry)) {
        waitingSponsors.add(entry);
        continue;
      }

      paced.add(entry);
      organicSinceLastSponsor += 1;

      if (organicSinceLastSponsor >= minOrganicGap &&
          waitingSponsors.isNotEmpty) {
        paced.add(markSponsor(waitingSponsors.removeFirst()));
        organicSinceLastSponsor = 0;
      }
    }

    while (waitingSponsors.isNotEmpty) {
      if (paced.isEmpty) {
        paced.add(markSponsor(waitingSponsors.removeFirst(), fallback: true));
        organicSinceLastSponsor = 0;
        continue;
      }

      if (organicSinceLastSponsor >= minOrganicGap) {
        paced.add(markSponsor(waitingSponsors.removeFirst()));
        organicSinceLastSponsor = 0;
      } else {
        break;
      }
    }

    return paced;
  }

  double _computeRecencyBoost(DateTime? publishedAt) {
    if (publishedAt == null) {
      return 0;
    }
    final now = _now().toUtc();
    final ts = publishedAt.toUtc();
    final diff = now.difference(ts);
    if (diff.isNegative) {
      return 0.5;
    }
    final hours = diff.inMinutes / 60;
    if (hours < 1) {
      return 1.0;
    }
    if (hours < 6) {
      return 0.8;
    }
    if (hours < 24) {
      return 0.5;
    }
    if (hours < 72) {
      return 0.25;
    }
    return 0.1;
  }
}
