import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/models/feed_entry.dart';
import '../domain/models/feed_segment.dart';
import '../domain/models/sponsor_campaign.dart';
import '../domain/repositories/feed_repository.dart';
import 'feed_api_config.dart';
import 'remote_feed_repository.dart';

class HybridFeedRepository implements FeedRepository {
  HybridFeedRepository({
    required RemoteFeedRepository remote,
    FeedApiConfig? config,
    Random? random,
  }) : _remote = remote,
       _config = config ?? const FeedApiConfig(),
       _random = random ?? Random.secure();

  final RemoteFeedRepository _remote;
  final FeedApiConfig _config;
  final Random _random;

  final Map<String, Completer<void>> _recommendedRefreshSignals = {};

  @override
  Stream<List<FeedEntry>> watchEntries({
    required FeedSegment segment,
    required String userId,
  }) {
    switch (segment) {
      case FeedSegment.following:
        return _watchFollowing(userId);
      case FeedSegment.recommended:
        return _watchRecommended(userId);
    }
  }

  @override
  Stream<List<SponsorCampaign>> watchSponsorCampaigns({
    required String userId,
  }) {
    final fallback = _fallbackSponsors();
    return _remote
        .watchSponsorCampaigns(userId)
        .transform(
          _withFallback<SponsorCampaign>(
            fallback: fallback,
            logLabel: 'Sponsor stream',
          ),
        );
  }

  @override
  Future<void> refreshRecommended({required String userId}) async {
    final signal = _recommendedRefreshSignals[userId];
    if (signal != null && !signal.isCompleted) {
      signal.complete();
      return;
    }

    try {
      await _remote.fetchRecommendedFeed(userId);
    } catch (error, stackTrace) {
      debugPrint('Recommended feed refresh failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Stream<List<FeedEntry>> _watchFollowing(String userId) {
    final fallback = _fallbackFollowing();
    return _remote
        .watchFollowingFeed(userId)
        .transform(
          _withFallback<FeedEntry>(
            fallback: fallback,
            logLabel: 'Following feed',
          ),
        );
  }

  Stream<List<FeedEntry>> _watchRecommended(String userId) {
    return Stream.multi((controller) {
      var isActive = true;

      controller.onCancel = () {
        isActive = false;
        final signal = _recommendedRefreshSignals.remove(userId);
        if (signal != null && !signal.isCompleted) {
          signal.complete();
        }
      };

      unawaited(() async {
        while (isActive) {
          final refreshSignal = Completer<void>();
          _recommendedRefreshSignals[userId] = refreshSignal;

          List<FeedEntry> entries;
          try {
            entries = await _remote.fetchRecommendedFeed(userId);
          } catch (error, stackTrace) {
            debugPrint('Recommended feed error: $error');
            debugPrint('$stackTrace');
            entries = const <FeedEntry>[];
          }

          if (!isActive) {
            _recommendedRefreshSignals.remove(userId);
            break;
          }

          final payload = entries.isEmpty ? _fallbackRecommended() : entries;
          controller.add(payload);

          final waitDuration = Duration(
            seconds: _config.recommendedRefreshIntervalSeconds
                .clamp(30, 600)
                .toInt(),
          );

          try {
            await Future.any([
              Future.delayed(waitDuration),
              refreshSignal.future,
            ]);
          } catch (_) {
            // no-op
          } finally {
            final stored = _recommendedRefreshSignals[userId];
            if (identical(stored, refreshSignal)) {
              _recommendedRefreshSignals.remove(userId);
            }
          }
        }
      }());
    });
  }

  StreamTransformer<List<T>, List<T>> _withFallback<T>({
    required List<T> fallback,
    required String logLabel,
  }) {
    return StreamTransformer<List<T>, List<T>>.fromHandlers(
      handleData: (data, sink) {
        if (data.isEmpty) {
          sink.add(fallback);
        } else {
          sink.add(data);
        }
      },
      handleError: (error, stackTrace, sink) {
        debugPrint('$logLabel error: $error');
        debugPrint('$stackTrace');
        sink.add(fallback);
      },
    );
  }

  List<FeedEntry> _fallbackFollowing() =>
      _sampleEntries('Takip', seedOffset: 7);

  List<FeedEntry> _fallbackRecommended() =>
      _sampleEntries('Öneri', seedOffset: 19);

  List<SponsorCampaign> _fallbackSponsors() {
    return [
      SponsorCampaign(
        id: 'sponsor-1',
        title: 'Cringe Market x Banka CG',
        description: 'İlk paylaşımda ekstra CG kazanım kampanyası başladı.',
        ctaText: 'Detayları Gör',
        startColor: const Color(0xFF512DA8),
        endColor: const Color(0xFF9575CD),
      ),
      SponsorCampaign(
        id: 'sponsor-2',
        title: 'Creator Finansmanı',
        description: 'Stüdyo kurulumları için 0 faizli finansman fırsatı.',
        ctaText: 'Başvur',
        startColor: const Color(0xFF00695C),
        endColor: const Color(0xFF26A69A),
      ),
    ];
  }

  List<FeedEntry> _sampleEntries(String tagPrefix, {int seedOffset = 0}) {
    return List<FeedEntry>.generate(3, (index) {
      final seed = _random.nextInt(0xFFFFFF) + seedOffset;
      final color = Color(0xFF000000 | seed);
      return FeedEntry(
        id: 'sample-$tagPrefix-$index',
        author: 'CG Kullanıcısı ${index + 1}',
        title: 'Örnek başlık ${index + 1}',
        excerpt: 'Gerçek veri hazır olana kadar placeholder içerik gösterilir.',
        relativeTime: '${(index + 1) * 5} dk',
        tag: '$tagPrefix ${index + 1}',
        likeCount: 120 - (index * 11),
        commentCount: 32 - (index * 5),
        accentColor: color,
      );
    });
  }
}
