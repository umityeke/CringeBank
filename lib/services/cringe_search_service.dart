import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../utils/search_normalizer.dart';

enum SearchSortBy {
  relevance('Relevans'),
  newest('En Yeni'),
  oldest('En Eski'),
  highestKrep('En Yüksek Krep'),
  lowestKrep('En Düşük Krep'),
  mostLiked('En Beğenili'),
  mostCommented('En Çok Yorumlanan');

  const SearchSortBy(this.displayName);
  final String displayName;
}

class SearchFilter {
  final Set<CringeCategory> categories;
  final double? minKrepLevel;
  final double? maxKrepLevel;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? onlyAnonymous;
  final bool? onlyPremium;
  final int? minLikes;
  final List<String> tags;

  SearchFilter({
    this.categories = const {},
    this.minKrepLevel,
    this.maxKrepLevel,
    this.startDate,
    this.endDate,
    this.onlyAnonymous,
    this.onlyPremium,
    this.minLikes,
    this.tags = const [],
  });

  SearchFilter copyWith({
    Set<CringeCategory>? categories,
    double? minKrepLevel,
    double? maxKrepLevel,
    DateTime? startDate,
    DateTime? endDate,
    bool? onlyAnonymous,
    bool? onlyPremium,
    int? minLikes,
    List<String>? tags,
  }) {
    return SearchFilter(
      categories: categories ?? this.categories,
      minKrepLevel: minKrepLevel ?? this.minKrepLevel,
      maxKrepLevel: maxKrepLevel ?? this.maxKrepLevel,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      onlyAnonymous: onlyAnonymous ?? this.onlyAnonymous,
      onlyPremium: onlyPremium ?? this.onlyPremium,
      minLikes: minLikes ?? this.minLikes,
      tags: tags ?? this.tags,
    );
  }

  bool get isEmpty =>
      categories.isEmpty &&
      minKrepLevel == null &&
      maxKrepLevel == null &&
      startDate == null &&
      endDate == null &&
      onlyAnonymous == null &&
      onlyPremium == null &&
      minLikes == null &&
      tags.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((c) => c.name).toList(),
      'minKrepLevel': minKrepLevel,
      'maxKrepLevel': maxKrepLevel,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'onlyAnonymous': onlyAnonymous,
      'onlyPremium': onlyPremium,
      'minLikes': minLikes,
      'tags': tags,
    };
  }
}

class SearchResult {
  final List<CringeEntry> entries;
  final int totalCount;
  final String? aiSuggestion;
  final List<String> relatedSearches;
  final Map<CringeCategory, int> categoryDistribution;
  final Duration searchDuration;

  SearchResult({
    required this.entries,
    required this.totalCount,
    this.aiSuggestion,
    this.relatedSearches = const [],
    this.categoryDistribution = const {},
    required this.searchDuration,
  });
}

class UserSearchResult {
  final List<User> users;
  final int totalCount;
  final Duration searchDuration;
  final List<String> matchedTokens;

  const UserSearchResult({
    required this.users,
    required this.totalCount,
    required this.searchDuration,
    this.matchedTokens = const [],
  });
}

class CringeSearchService {
  static bool _isInitialized = false;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search data
  static final List<String> _recentSearches = [];
  static final Set<String> _trendingTags = {};

  // Initialize search service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _generateTrendingTags();
    _isInitialized = true;
  }

  // Generate trending tags
  static void _generateTrendingTags() {
    _trendingTags.addAll([
      'zoom_fail',
      'aşk_acısı',
      'okul_rezilligi',
      'iş_kazası',
      'anne_baba',
      'sosyal_medya',
      'yanlış_mesaj',
      'elevator_krizi',
      'restaurant_faciası',
      'crush_drama',
      'öğretmen_karışıklığı',
      'spor_salonu',
      'alışveriş_merkezi',
    ]);
  }

  // Main search function
  static Future<SearchResult> search({
    required String query,
    SearchFilter? filter,
    SearchSortBy sortBy = SearchSortBy.relevance,
    int page = 1,
    int limit = 20,
  }) async {
    final startTime = DateTime.now();

    // Add to recent searches
    if (query.isNotEmpty && !_recentSearches.contains(query)) {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    }

  final fetchLimit = ((page * limit).clamp(20, 500)).toInt();
    final fetchedEntries = await _fetchEntriesFromFirestore(limit: fetchLimit);

    if (fetchedEntries.isNotEmpty) {
      final tags = <String>{};
      for (final entry in fetchedEntries) {
        tags.addAll(entry.etiketler.map((tag) => tag.toLowerCase()));
      }
      if (tags.isNotEmpty) {
        _trendingTags
          ..clear()
          ..addAll(tags.take(25));
      }
    }

    List<CringeEntry> filteredEntries = List.from(fetchedEntries);

    // Text search
    if (query.isNotEmpty) {
      filteredEntries = filteredEntries.where((entry) {
        final searchText =
            '${entry.baslik} ${entry.aciklama} ${entry.etiketler.join(' ')}'
                .toLowerCase();
        return searchText.contains(query.toLowerCase());
      }).toList();
    }

    // Apply filters
    if (filter != null && !filter.isEmpty) {
      filteredEntries = _applyFilters(filteredEntries, filter);
    }

    // Sort entries
    _sortEntries(filteredEntries, sortBy);

    // Calculate pagination
    final totalCount = filteredEntries.length;
    final startIndex = (page - 1) * limit;
    final endIndex = (startIndex + limit).clamp(0, totalCount);
    final paginatedEntries = filteredEntries.sublist(
      startIndex.clamp(0, totalCount),
      endIndex,
    );

    // Generate category distribution
    final categoryDist = <CringeCategory, int>{};
    for (final entry in filteredEntries) {
      categoryDist[entry.kategori] = (categoryDist[entry.kategori] ?? 0) + 1;
    }

    final searchDuration = DateTime.now().difference(startTime);

    return SearchResult(
      entries: paginatedEntries,
      totalCount: totalCount,
      aiSuggestion: query.isNotEmpty ? _generateAISuggestion(query) : null,
      relatedSearches: _generateRelatedSearches(query),
      categoryDistribution: categoryDist,
      searchDuration: searchDuration,
    );
  }

  static Future<UserSearchResult> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    final normalizedQuery = SearchNormalizer.normalizeForSearch(query);
    if (normalizedQuery.length < 2) {
      return const UserSearchResult(
        users: [],
        totalCount: 0,
        searchDuration: Duration.zero,
        matchedTokens: [],
      );
    }

    final tokens = SearchNormalizer.tokenizeQuery(normalizedQuery, maxTokens: 10);
    if (tokens.isEmpty) {
      return const UserSearchResult(
        users: [],
        totalCount: 0,
        searchDuration: Duration.zero,
        matchedTokens: [],
      );
    }

    final startTime = DateTime.now();

    try {
      final queryTokens = tokens.take(10).toList(growable: false);

      final snapshot = await _firestore
          .collection('users')
          .where('searchKeywords', arrayContainsAny: queryTokens)
          .limit(limit * 3)
          .get();

      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return User.fromMap({
          ...data,
          'id': doc.id,
        });
      }).toList(growable: true);

      final fetchedIds = users.map((user) => user.id).toSet();
      final normalizedQueryNoSpaces = normalizedQuery.replaceAll(' ', '');

      if (users.length < limit && normalizedQueryNoSpaces.isNotEmpty) {
        final usernameSnapshots = await Future.wait([
          _firestore
              .collection('users')
              .where('usernameLower', isEqualTo: normalizedQueryNoSpaces)
              .limit(5)
              .get(),
          _firestore
              .collection('users')
              .where('usernameLower', isEqualTo: '@$normalizedQueryNoSpaces')
              .limit(5)
              .get(),
        ]);

        for (final snap in usernameSnapshots) {
          for (final doc in snap.docs) {
            if (fetchedIds.contains(doc.id)) continue;
            final data = doc.data();
            final user = User.fromMap({
              ...data,
              'id': doc.id,
            });
            users.add(user);
            fetchedIds.add(user.id);
          }
        }
      }

      if (users.length < limit) {
        final fallbackSnapshot = await _firestore
            .collection('users')
            .orderBy('lastActive', descending: true)
            .limit(limit * 2)
            .get();

        for (final doc in fallbackSnapshot.docs) {
          if (fetchedIds.contains(doc.id)) continue;
          final data = doc.data();
          final user = User.fromMap({
            ...data,
            'id': doc.id,
          });

          final fallbackScore = _scoreUserMatch(
            user: user,
            tokens: tokens,
            normalizedQuery: normalizedQuery,
            normalizedQueryNoSpaces: normalizedQueryNoSpaces,
          );

          if (fallbackScore > 0) {
            users.add(user);
            fetchedIds.add(user.id);
          }
        }
      }

      final scored = users
          .map((user) => _UserScore(
                user: user,
                score: _scoreUserMatch(
                  user: user,
                  tokens: tokens,
                  normalizedQuery: normalizedQuery,
                  normalizedQueryNoSpaces: normalizedQueryNoSpaces,
                ),
              ))
          .toList();

      scored.sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;

        final verifyCompare = (b.user.isVerified ? 1 : 0)
            .compareTo(a.user.isVerified ? 1 : 0);
        if (verifyCompare != 0) return verifyCompare;

        final followerCompare = b.user.followersCount.compareTo(a.user.followersCount);
        if (followerCompare != 0) return followerCompare;

        return b.user.lastActive.compareTo(a.user.lastActive);
      });

      final topUsers = scored.take(limit).map((item) => item.user).toList(growable: false);

      return UserSearchResult(
        users: topUsers,
        totalCount: scored.length,
        searchDuration: DateTime.now().difference(startTime),
        matchedTokens: tokens,
      );
    } catch (e) {
      // ignore: avoid_print
      print('User search error: $e');
      return UserSearchResult(
        users: const [],
        totalCount: 0,
        searchDuration: DateTime.now().difference(startTime),
        matchedTokens: tokens,
      );
    }
  }

  // Apply search filters
  static List<CringeEntry> _applyFilters(
    List<CringeEntry> entries,
    SearchFilter filter,
  ) {
    return entries.where((entry) {
      // Category filter
      if (filter.categories.isNotEmpty &&
          !filter.categories.contains(entry.kategori)) {
        return false;
      }

      // Krep level filter
      if (filter.minKrepLevel != null &&
          entry.krepSeviyesi < filter.minKrepLevel!) {
        return false;
      }
      if (filter.maxKrepLevel != null &&
          entry.krepSeviyesi > filter.maxKrepLevel!) {
        return false;
      }

      // Date filter
      if (filter.startDate != null && entry.createdAt.isBefore(filter.startDate!)) {
        return false;
      }
      if (filter.endDate != null && entry.createdAt.isAfter(filter.endDate!)) {
        return false;
      }

      // Anonymous filter
      if (filter.onlyAnonymous != null &&
          entry.isAnonim != filter.onlyAnonymous!) {
        return false;
      }

      // Likes filter
      if (filter.minLikes != null && entry.begeniSayisi < filter.minLikes!) {
        return false;
      }

      // Tags filter
      if (filter.tags.isNotEmpty) {
        final hasTag = filter.tags.any((tag) =>
            entry.etiketler.any((entryTag) =>
                entryTag.toLowerCase().contains(tag.toLowerCase())));
        if (!hasTag) return false;
      }

      return true;
    }).toList();
  }

  // Sort entries based on criteria
  static void _sortEntries(List<CringeEntry> entries, SearchSortBy sortBy) {
    switch (sortBy) {
      case SearchSortBy.newest:
        entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SearchSortBy.oldest:
        entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SearchSortBy.highestKrep:
        entries.sort((a, b) => b.krepSeviyesi.compareTo(a.krepSeviyesi));
        break;
      case SearchSortBy.lowestKrep:
        entries.sort((a, b) => a.krepSeviyesi.compareTo(b.krepSeviyesi));
        break;
      case SearchSortBy.mostLiked:
        entries.sort((a, b) => b.begeniSayisi.compareTo(a.begeniSayisi));
        break;
      case SearchSortBy.mostCommented:
        entries.sort((a, b) => b.yorumSayisi.compareTo(a.yorumSayisi));
        break;
      case SearchSortBy.relevance:
        // Keep current order for relevance (already filtered by text match)
        break;
    }
  }

  // Generate AI suggestion for search query
  static String? _generateAISuggestion(String query) {
    if (query.isEmpty) return null;

    return null; // Removed mock suggestions
  }

  // Generate related searches
  static List<String> _generateRelatedSearches(String query) {
    if (query.isEmpty) return [];
    return []; // Return empty list - no mock suggestions
  }

  static Future<List<CringeEntry>> _fetchEntriesFromFirestore({
    required int limit,
  }) async {
    try {
    final safeLimit = limit.clamp(1, 500).toInt();
    final snapshot = await _firestore
      .collection('cringe_entries')
      .orderBy('createdAt', descending: true)
      .limit(safeLimit)
      .get();

      final entries = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CringeEntry.fromFirestore(data);
      }).toList();

      return entries;
    } catch (e) {
      // ignore: avoid_print
      print('CringeSearchService Firestore fetch error: $e');
      return [];
    }
  }

  // Get trending tags
  static List<String> getTrendingTags() {
    return _trendingTags.toList()..shuffle();
  }

  // Get recent searches
  static List<String> getRecentSearches() {
    return List.from(_recentSearches);
  }

  // Clear recent searches
  static void clearRecentSearches() {
    _recentSearches.clear();
  }

  // Get search suggestions based on input
  static List<String> getSearchSuggestions(String input) {
    if (input.isEmpty) return [];

    final suggestions = <String>[];
    
    // Add matching recent searches
    suggestions.addAll(_recentSearches
        .where((search) => search.toLowerCase().contains(input.toLowerCase()))
        .take(3));

    // Add matching trending tags
    suggestions.addAll(_trendingTags
        .where((tag) => tag.toLowerCase().contains(input.toLowerCase()))
        .take(5));

    return suggestions.take(8).toList();
  }
}

  class _UserScore {
    final User user;
    final int score;

    const _UserScore({
      required this.user,
      required this.score,
    });
  }

  int _scoreUserMatch({
    required User user,
    required List<String> tokens,
    required String normalizedQuery,
    required String normalizedQueryNoSpaces,
  }) {
    final keywordSet = SearchNormalizer.generateUserSearchKeywords(
      fullName: user.fullName,
      username: user.username,
      email: user.email,
    ).toSet();

    final normalizedFullName = SearchNormalizer.normalizeForSearch(user.fullName);
    final normalizedUsername = SearchNormalizer
        .normalizeForSearch(user.username)
        .replaceAll(RegExp(r'[@\s]+'), '');

    var score = 0;

    for (final token in tokens) {
      if (keywordSet.contains(token)) {
        score += 8;
      } else if (keywordSet.any((kw) => kw.contains(token))) {
        score += 4;
      }

      if (normalizedFullName.contains(token)) {
        score += 2;
      }
    }

    if (normalizedFullName.startsWith(normalizedQuery) && normalizedQuery.isNotEmpty) {
      score += 10;
    }

    if (normalizedUsername.startsWith(normalizedQueryNoSpaces) &&
        normalizedQueryNoSpaces.isNotEmpty) {
      score += 12;
    }

    if (normalizedUsername == normalizedQueryNoSpaces && normalizedUsername.isNotEmpty) {
      score += 15;
    }

    if (normalizedFullName == normalizedQuery && normalizedFullName.isNotEmpty) {
      score += 12;
    }

    if (user.isVerified) {
      score += 3;
    }

    if (user.isPremium) {
      score += 1;
    }

    score += (user.followersCount ~/ 1000).clamp(0, 5);

    final daysSinceActive = DateTime.now().difference(user.lastActive).inDays;
    if (daysSinceActive <= 7) {
      score += 2;
    } else if (daysSinceActive <= 30) {
      score += 1;
    }

    return score;
  }