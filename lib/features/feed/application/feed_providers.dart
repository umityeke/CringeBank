import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/session/session_providers.dart';
import '../domain/models/feed_entry.dart';
import '../domain/models/feed_segment.dart';
import '../domain/models/sponsor_campaign.dart';
import '../domain/repositories/feed_repository.dart';
import 'feed_ranking_service.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return sl<FeedRepository>();
});

final feedRankingServiceProvider = Provider<FeedRankingService>((ref) {
  return FeedRankingService();
});

final feedEntriesProvider = StreamProvider.family<List<FeedEntry>, FeedSegment>((ref, segment) {
  final repository = ref.watch(feedRepositoryProvider);
  final session = ref.watch(sessionControllerProvider);
  final ranking = ref.watch(feedRankingServiceProvider);
  final userId = session.identifier;
  if (userId == null) {
    return Stream.value(const <FeedEntry>[]);
  }
  return repository
      .watchEntries(segment: segment, userId: userId)
      .map((entries) => ranking.applyRanking(entries, segment: segment));
});

final feedSponsorCampaignsProvider = StreamProvider<List<SponsorCampaign>>((ref) {
  final repository = ref.watch(feedRepositoryProvider);
  final session = ref.watch(sessionControllerProvider);
  final userId = session.identifier;
  if (userId == null) {
    return Stream.value(const <SponsorCampaign>[]);
  }
  return repository.watchSponsorCampaigns(userId: userId);
});

final feedRefreshRecommendedProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  final session = ref.watch(sessionControllerProvider);
  final userId = session.identifier;
  if (userId == null) {
    return;
  }
  await repository.refreshRecommended(userId: userId);
});
