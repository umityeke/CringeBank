import 'dart:async';
import '../models/cringe_entry.dart';

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

class CringeSearchService {
  static bool _isInitialized = false;

  // Search data
  static final List<CringeEntry> _allEntries = [];
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

    // Filter entries - since _allEntries is empty, this will return empty results
    List<CringeEntry> filteredEntries = _allEntries;

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

  // Add entry to search index (for real data integration)
  static void addEntry(CringeEntry entry) {
    _allEntries.add(entry);
  }

  // Remove entry from search index
  static void removeEntry(String entryId) {
    _allEntries.removeWhere((entry) => entry.id == entryId);
  }

  // Update entry in search index
  static void updateEntry(CringeEntry entry) {
    final index = _allEntries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _allEntries[index] = entry;
    }
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