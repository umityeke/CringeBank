import 'dart:async';
import 'dart:math';

import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../utils/search_normalizer.dart';
import 'cringe_search_service.dart';

class StyleSearchSection<T> {
  final List<T> items;
  final int totalCount;
  final String? nextCursor;
  final Duration fetchDuration;

  const StyleSearchSection({
    required this.items,
    required this.totalCount,
    required this.fetchDuration,
    this.nextCursor,
  });
}

enum StyleSearchEntityType { account, hashtag, place, post }

class StyleSearchTopResult {
  final StyleSearchEntityType type;
  final Object item;
  final double score;

  const StyleSearchTopResult({
    required this.type,
    required this.item,
    required this.score,
  });
}

class StyleSearchHashtag {
  final String tag;
  final int postCount;
  final double trendScore;
  final bool isTrending;

  const StyleSearchHashtag({
    required this.tag,
    required this.postCount,
    required this.trendScore,
    this.isTrending = false,
  });
}

class StyleSearchPlace {
  final String placeId;
  final String name;
  final String? city;
  final String? country;
  final double popularityScore;

  const StyleSearchPlace({
    required this.placeId,
    required this.name,
    this.city,
    this.country,
    this.popularityScore = 0,
  });
}

class StyleSearchResponse {
  final String query;
  final NormalizedText normalizedQuery;
  final List<StyleSearchTopResult> top;
  final StyleSearchSection<User> accounts;
  final StyleSearchSection<StyleSearchHashtag> hashtags;
  final StyleSearchSection<StyleSearchPlace> places;
  final StyleSearchSection<CringeEntry> posts;
  final Duration totalDuration;
  final Map<String, Duration> timings;
  final List<String> recentSearches;
  final List<String> suggestions;

  const StyleSearchResponse({
    required this.query,
    required this.normalizedQuery,
    required this.top,
    required this.accounts,
    required this.hashtags,
    required this.places,
    required this.posts,
    required this.totalDuration,
    required this.timings,
    required this.recentSearches,
    required this.suggestions,
  });

  bool get hasAnyResults =>
      top.isNotEmpty ||
      accounts.items.isNotEmpty ||
      hashtags.items.isNotEmpty ||
      places.items.isNotEmpty ||
      posts.items.isNotEmpty;
}

class StyleSearchService {
  static Future<StyleSearchResponse> search({
    required String query,
    SearchFilter? filter,
    SearchSortBy sortBy = SearchSortBy.relevance,
    int limitPerSection = 8,
    int postsLimit = 10,
  }) async {
    await CringeSearchService.initialize();
    final totalWatch = Stopwatch()..start();
    final normalized = SearchNormalizer.buildNormalization(query);
    final hasMeaningfulQuery =
        normalized.ascii.length >= 2 || normalized.normalizedTr.length >= 2;

    final timings = <String, Duration>{};

    SearchResult? postResult;
    UserSearchResult? accountResult;

    final futures = <Future<void>>[];

    final postsWatch = Stopwatch()..start();
    futures.add(Future(() async {
      postResult = await CringeSearchService.search(
        query: hasMeaningfulQuery ? query : '',
        filter: filter,
        sortBy: sortBy,
        limit: postsLimit,
      );
      timings['posts'] = postsWatch.elapsed;
    }));

    final accountsWatch = Stopwatch()..start();
    futures.add(Future(() async {
      if (hasMeaningfulQuery) {
        accountResult = await CringeSearchService.searchUsers(
          query: query,
          limit: limitPerSection,
        );
      } else {
        accountResult = const UserSearchResult(
          users: [],
          totalCount: 0,
          searchDuration: Duration.zero,
          matchedTokens: [],
        );
      }
      timings['accounts'] = accountsWatch.elapsed;
    }));

    await Future.wait(futures);

    postResult ??= SearchResult(
      entries: const [],
      totalCount: 0,
      searchDuration: Duration.zero,
    );
    accountResult ??= const UserSearchResult(
      users: [],
      totalCount: 0,
      searchDuration: Duration.zero,
    );

    final hashtagSection = _buildHashtagSection(
      normalized,
      postResult!,
      limitPerSection: limitPerSection,
      hasQuery: hasMeaningfulQuery,
    );
    timings['hashtags'] = hashtagSection.fetchDuration;

    final placesSection = _buildPlaceSection();
    timings['places'] = placesSection.fetchDuration;

    final accountsSection = StyleSearchSection<User>(
      items: accountResult!.users,
      totalCount: accountResult!.totalCount,
      fetchDuration: accountResult!.searchDuration,
    );

    final postsSection = StyleSearchSection<CringeEntry>(
      items: postResult!.entries,
      totalCount: postResult!.totalCount,
      fetchDuration: postResult!.searchDuration,
    );

    final topResults = _buildTopSection(
      accountsSection,
      hashtagSection,
      placesSection,
      postsSection,
      normalized,
    );

    totalWatch.stop();

    final suggestions = _buildSuggestions(
      normalized,
      hasMeaningfulQuery,
      accountsSection,
      hashtagSection,
    );

    return StyleSearchResponse(
      query: query,
      normalizedQuery: normalized,
      top: topResults,
      accounts: accountsSection,
      hashtags: hashtagSection,
      places: placesSection,
      posts: postsSection,
      totalDuration: totalWatch.elapsed,
      timings: timings,
      recentSearches: CringeSearchService.recentSearches,
      suggestions: suggestions,
    );
  }

  static StyleSearchSection<StyleSearchHashtag> _buildHashtagSection(
    NormalizedText normalized,
    SearchResult postResult, {
    required int limitPerSection,
    required bool hasQuery,
  }) {
    final watch = Stopwatch()..start();
    final Map<String, _HashtagStats> stats = {};
    final asciiQuery = normalized.ascii;
    final trQuery = normalized.normalizedTr;
    final trending = CringeSearchService.trendingTags;

    for (final entry in postResult.entries) {
      for (final rawTag in entry.etiketler) {
        final normalizedTag = SearchNormalizer.buildNormalization(rawTag);
        if (normalizedTag.ascii.isEmpty) continue;

        final key = normalizedTag.ascii;
        final current = stats[key] ?? _HashtagStats(tag: rawTag);
        current.count++;
        current.isTrending = current.isTrending ||
            trending.any((tag) =>
                SearchNormalizer.buildNormalization(tag).ascii ==
                normalizedTag.ascii);

        if (asciiQuery.isNotEmpty &&
            normalizedTag.ascii.startsWith(asciiQuery)) {
          current.prefixMatches++;
        }
        if (trQuery.isNotEmpty &&
            normalizedTag.normalizedTr.startsWith(trQuery)) {
          current.prefixMatches++;
        }
        stats[key] = current;
      }
    }

    if (!hasQuery) {
      for (final tag in trending) {
        final normalizedTag = SearchNormalizer.buildNormalization(tag);
        final key = normalizedTag.ascii;
        final current = stats[key] ?? _HashtagStats(tag: tag);
        current.isTrending = true;
        current.count = max(current.count, 1);
        stats[key] = current;
      }
    }

    final hashtags = stats.values.map((value) {
      final baseScore = log(value.count + 1);
      final prefixBoost = value.prefixMatches > 0 ? 0.6 : 0.0;
      final trendingBoost = value.isTrending ? 0.8 : 0.0;
      final score = baseScore + prefixBoost + trendingBoost;
      return _HashtagCandidate(
        tag: value.tag,
        count: value.count,
        score: score,
        isTrending: value.isTrending,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final items = hashtags
        .take(limitPerSection)
        .map((candidate) => StyleSearchHashtag(
              tag: candidate.tag,
              postCount: candidate.count,
              trendScore: candidate.score,
              isTrending: candidate.isTrending,
            ))
        .toList(growable: false);

    watch.stop();

    return StyleSearchSection<StyleSearchHashtag>(
      items: items,
      totalCount: hashtags.length,
      fetchDuration: watch.elapsed,
    );
  }

  static StyleSearchSection<StyleSearchPlace> _buildPlaceSection() {
    return const StyleSearchSection<StyleSearchPlace>(
      items: [],
      totalCount: 0,
      fetchDuration: Duration.zero,
    );
  }

  static List<StyleSearchTopResult> _buildTopSection(
    StyleSearchSection<User> accounts,
    StyleSearchSection<StyleSearchHashtag> hashtags,
    StyleSearchSection<StyleSearchPlace> places,
    StyleSearchSection<CringeEntry> posts,
    NormalizedText normalized,
  ) {
    final List<StyleSearchTopResult> results = [];

    final asciiQuery = normalized.ascii;

    for (var i = 0;
        i < min(3, accounts.items.length);
        i++) {
      final user = accounts.items[i];
      final score = _scoreAccount(user, asciiQuery, rank: i);
      results.add(StyleSearchTopResult(
        type: StyleSearchEntityType.account,
        item: user,
        score: score,
      ));
    }

    for (var i = 0;
        i < min(3, hashtags.items.length);
        i++) {
      final hashtag = hashtags.items[i];
      final score = _scoreHashtag(hashtag, asciiQuery, rank: i);
      results.add(StyleSearchTopResult(
        type: StyleSearchEntityType.hashtag,
        item: hashtag,
        score: score,
      ));
    }

    for (var i = 0; i < min(3, posts.items.length); i++) {
      final post = posts.items[i];
      final score = _scorePost(post, rank: i);
      results.add(StyleSearchTopResult(
        type: StyleSearchEntityType.post,
        item: post,
        score: score,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(6).toList(growable: false);
  }

  static List<String> _buildSuggestions(
    NormalizedText normalized,
    bool hasMeaningfulQuery,
    StyleSearchSection<User> accounts,
    StyleSearchSection<StyleSearchHashtag> hashtags,
  ) {
    if (!hasMeaningfulQuery) {
      return CringeSearchService.trendingTags.take(8).toList(growable: false);
    }

    final suggestions = <String>[];

    for (final user in accounts.items.take(4)) {
      suggestions.add('@${user.username}');
    }

    for (final hashtag in hashtags.items.take(4)) {
      suggestions.add('#${hashtag.tag}');
    }

    if (suggestions.isEmpty && normalized.ascii.isNotEmpty) {
      suggestions.add(normalized.ascii);
    }

    return suggestions.take(8).toList(growable: false);
  }

  static double _scoreAccount(User user, String asciiQuery, {int rank = 0}) {
    final followerBoost = log(user.followersCount + 1) / 10;
    final verifiedBoost = user.isVerified ? 0.2 : 0.0;
    final premiumBoost = user.isPremium ? 0.05 : 0.0;
    final base = 1.0 - min(rank, 5) * 0.1;
    final nameMatch = asciiQuery.isNotEmpty &&
            (user.username.toLowerCase().contains(asciiQuery) ||
                user.fullName.toLowerCase().contains(asciiQuery))
        ? 0.25
        : 0.0;
    return (base + followerBoost + verifiedBoost + premiumBoost + nameMatch)
        .clamp(0, 2.5);
  }

  static double _scoreHashtag(StyleSearchHashtag hashtag, String asciiQuery,
      {int rank = 0}) {
    final base = 0.9 - min(rank, 5) * 0.08;
    final popularity = log(hashtag.postCount + 1) / 8;
    final trendingBoost = hashtag.isTrending ? 0.25 : 0.0;
    final matchBoost = asciiQuery.isNotEmpty &&
            hashtag.tag.toLowerCase().startsWith(asciiQuery)
        ? 0.2
        : 0.0;
    return (base + popularity + trendingBoost + matchBoost)
        .clamp(0, 2.0);
  }

  static double _scorePost(CringeEntry entry, {int rank = 0}) {
    final base = 0.8 - min(rank, 5) * 0.1;
    final popularity = log(entry.begeniSayisi + entry.yorumSayisi + 1) / 8;
    final recencyMinutes =
        DateTime.now().difference(entry.createdAt).inMinutes;
    final recencyBoost = recencyMinutes <= 0
        ? 0.3
        : max(0.0, 0.3 - log(recencyMinutes + 1) / 10);
    final premiumBoost = entry.isPremiumCringe ? 0.1 : 0.0;
    return (base + popularity + recencyBoost + premiumBoost).clamp(0, 2.0);
  }
}

class _HashtagStats {
  _HashtagStats({required this.tag});

  final String tag;
  int count = 0;
  bool isTrending = false;
  int prefixMatches = 0;
}

class _HashtagCandidate {
  _HashtagCandidate({
    required this.tag,
    required this.count,
    required this.score,
    required this.isTrending,
  });

  final String tag;
  final int count;
  final double score;
  final bool isTrending;
}
