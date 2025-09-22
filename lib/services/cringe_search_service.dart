import 'dart:async';
import 'dart:math';
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
  static final List<CringeEntry> _allEntries = [];
  static final List<String> _recentSearches = [];
  static final List<String> _trendingTags = [];
  static bool _isInitialized = false;

  // Initialize search service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _generateMockEntries();
    _generateTrendingTags();
    
    _isInitialized = true;
  }

  // Generate mock cringe entries for search
  static Future<void> _generateMockEntries() async {
    final random = Random();
    final titles = [
      'Sınıfın ortasında osurdum',
      'Crush\'uma yanlış mesaj attım',
      'Anne toplantısında rezil oldum',
      'İş görüşmesinde kravat takamadım',
      'Instagram story\'yi yanlış kişiye attım',
      'Elevator\'da yanlış kata bastım',
      'Kahveci\'de adımı yanlış söylediler',
      'Zoom toplantısında kamerayı açık unutmuşum',
      'Restoranda yanlış hesabı ödedim',
      'Eski sevgilimle karşılaştım',
      'Hoca\'ya "anne" diye seslendim',
      'Tiyatro oyununda yanlış repliği söyledim',
      'Düğünde yanlış dans ettim',
      'Uçakta yanlış koltuğa oturdum',
      'Bankada PIN\'imi unutmuşum',
      'Telefon konuşmasını yanlış anlama yaşadım',
      'Sosyal medya paylaşımında büyük hata',
      'Aile yemeğinde politically incorrect şaka',
      'Spor salonunda utanç verici an',
      'Alışveriş merkezinde kayboldum',
    ];

    final descriptions = [
      'Matematik dersinde sessizlik varken müthiş bir osuruk çıkardım. Herkes baktı, hoca bile güldü. 3 gün kimseyle konuşamadım.',
      'Arkadaşıma crush\'um hakkında yazdığım şeyi yanlışlıkla ona attım. "Keşke cesaretim olsa da konuşsam" yazmıştım.',
      'Annem parent-teacher meeting\'e geldi. Hoca "çocuğunuz çok sessiz" derken annem "evde hiç susmaz ki" dedi.',
      'İş görüşmesinde kravatımın ters takılı olduğunu fark ettim. 30 dakika boyunca konuştum öyle.',
      'Kendimle ilgili story\'yi yanlışlıkla ex\'ime attım. 2 saat sonra fark ettim.',
      'Asansörde 5. kata çıkacaktım, 15. kata bastım. Kimse bir şey demedi, ben de inmedim.',
      'Starbucks\'ta adımı "Ümit" dedim, "Üzüm" diye yazdılar. Düzeltmeye utandım.',
      'Zoom toplantısında kamera açıkken pijamalarla dolaşıyordum. Patron fark etti.',
      'Karşı masanın hesabını ödedim, garsona bahşiş de verdim. Kimse bir şey demedi.',
      'Eski sevgilimle karşılaştım, "Merhaba" diyecektim "Hoşçakal" dedim ve kaçtım.',
      'Lise öğretmenime "anne" diye seslendim. Tüm sınıf güldü, hoca da güldü.',
      'Okul oyununda "Ölmek ya da yaşamak" diyecektim "Yemek ya da yatmak" dedim.',
      'Düğünde vals varken ben tango yaptım. Herkes video çekti.',
      'Uçakta business class biletim var sanıp oturmuştim. 2 saat sonra fark ettiler.',
      'ATM\'de PIN\'imi unutmuştum, 5 kez yanlış girdim. Kartım bloke oldu.',
      'Telefonda arkadaşımla konuşurken başka birinin konuşmasına karıştım. 10 dakika yabancıyla konuştum.',
      'LinkedIn\'de çok kişisel bir post paylaştım. Patronum ve müşteriler gördü.',
      'Aile yemeğinde uygunsuz bir espri yaptım. Herkes sessizliğe büründü.',
      'Spor salonunda ağırlık kaldırırken pantolonumun lastik kısmı patladı.',
      'AVM\'de tuvaletleri ararken kadınlar tuvaletine girdim. İçeride 3 hanım vardı.',
    ];

    final categories = CringeCategory.values;
    final tags = [
      'okul', 'iş', 'aşk', 'aile', 'sosyal_medya', 'utanç', 'komik', 'epic_fail',
      'zoom', 'toplantı', 'hata', 'yanlışlık', 'karışıklık', 'eziklik',
      'arkadaş', 'crush', 'öğretmen', 'patron', 'anne', 'baba', 'restaurant',
      'telefon', 'mesaj', 'instagram', 'story', 'post', 'like', 'share',
    ];

    for (int i = 0; i < 50; i++) {
      final entry = CringeEntry(
        id: 'search_entry_$i',
        userId: 'user_${random.nextInt(100)}',
        authorName: 'Kullanıcı ${i + 1}',
        authorHandle: '@user${i + 1}',
        baslik: titles[i % titles.length],
        aciklama: descriptions[i % descriptions.length],
        kategori: categories[random.nextInt(categories.length)],
        krepSeviyesi: 1.0 + (random.nextDouble() * 9.0), // 1.0-10.0
        createdAt: DateTime.now().subtract(Duration(
          days: random.nextInt(365),
          hours: random.nextInt(24),
        )),
        etiketler: List.generate(
          random.nextInt(4) + 1,
          (index) => tags[random.nextInt(tags.length)],
        ).toSet().toList(),
        isAnonim: random.nextBool(),
        begeniSayisi: random.nextInt(100),
        yorumSayisi: random.nextInt(50),

        borsaDegeri: random.nextBool() ? random.nextDouble() * 1000 : null,
      );
      
      _allEntries.add(entry);
    }
  }

  // Generate trending tags
  static void _generateTrendingTags() {
    _trendingTags.addAll([
      'zoom_fail', 'aşk_acısı', 'okul_rezilligi', 'iş_kazası', 'anne_baba',
      'sosyal_medya', 'yanlış_mesaj', 'elevator_krizi', 'restaurant_faciası',
      'crush_drama', 'öğretmen_karışıklığı', 'spor_salonu', 'alışveriş_merkezi',
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

    // Filter entries
    List<CringeEntry> filteredEntries = _allEntries;
    
    // Text search
    if (query.isNotEmpty) {
      filteredEntries = filteredEntries.where((entry) {
        final searchText = '${entry.baslik} ${entry.aciklama} ${entry.etiketler.join(' ')}'.toLowerCase();
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
    final categoryDistribution = <CringeCategory, int>{};
    for (final entry in filteredEntries) {
      categoryDistribution[entry.kategori] = 
          (categoryDistribution[entry.kategori] ?? 0) + 1;
    }

    // Generate AI suggestion if query is not empty
    String? aiSuggestion;
    if (query.isNotEmpty && totalCount < 5) {
      aiSuggestion = await _generateAISuggestion(query);
    }

    // Generate related searches
    final relatedSearches = _generateRelatedSearches(query);

    final searchDuration = DateTime.now().difference(startTime);

    return SearchResult(
      entries: paginatedEntries,
      totalCount: totalCount,
      aiSuggestion: aiSuggestion,
      relatedSearches: relatedSearches,
      categoryDistribution: categoryDistribution,
      searchDuration: searchDuration,
    );
  }

  // Apply filters to entries
  static List<CringeEntry> _applyFilters(List<CringeEntry> entries, SearchFilter filter) {
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
      if (filter.startDate != null && 
          entry.createdAt.isBefore(filter.startDate!)) {
        return false;
      }
      if (filter.endDate != null && 
          entry.createdAt.isAfter(filter.endDate!)) {
        return false;
      }

      // Anonymous filter
      if (filter.onlyAnonymous != null && 
          entry.isAnonim != filter.onlyAnonymous!) {
        return false;
      }

      // Premium filter
      if (filter.onlyPremium != null && 
          entry.isPremiumCringe != filter.onlyPremium!) {
        return false;
      }

      // Likes filter
      if (filter.minLikes != null && 
          entry.begeniSayisi < filter.minLikes!) {
        return false;
      }

      // Tags filter
      if (filter.tags.isNotEmpty) {
        final hasMatchingTag = filter.tags.any((tag) => 
            entry.etiketler.any((entryTag) => 
                entryTag.toLowerCase().contains(tag.toLowerCase())));
        if (!hasMatchingTag) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Sort entries based on sort criteria
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
        // For relevance, entries are already in good order
        // Could implement more sophisticated relevance scoring here
        break;
    }
  }

  // Generate AI suggestion for better search
  static Future<String?> _generateAISuggestion(String query) async {
    try {
      // This would use real AI in production
      final mockSuggestions = [
        'Daha genel terimler kullanmayı dene: "${_getGeneralTerm(query)}"',
        'Farklı kelimelerle ara: "${_getSynonym(query)}"',
        'Kategori seçerek aramayı daralt',
        'Krep seviyesi filtresi kullan',
        'Son 30 gündeki paylaşımları filtrele',
      ];
      
      final random = Random();
      return mockSuggestions[random.nextInt(mockSuggestions.length)];
    } catch (e) {
      return null;
    }
  }

  // Get general term for suggestion
  static String _getGeneralTerm(String query) {
    final generalTerms = {
      'zoom': 'toplantı',
      'instagram': 'sosyal medya',
      'whatsapp': 'mesaj',
      'crush': 'aşk',
      'hoca': 'öğretmen',
      'patron': 'iş',
      'anne': 'aile',
      'baba': 'aile',
    };
    
    for (final entry in generalTerms.entries) {
      if (query.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }
    
    return 'utanç';
  }

  // Get synonym for suggestion
  static String _getSynonym(String query) {
    final synonyms = {
      'utanç': 'rezillik',
      'rezillik': 'utanç',
      'komik': 'eğlenceli',
      'hata': 'yanlışlık',
      'fail': 'başarısızlık',
      'epic': 'büyük',
    };
    
    for (final entry in synonyms.entries) {
      if (query.toLowerCase().contains(entry.key)) {
        return query.toLowerCase().replaceAll(entry.key, entry.value);
      }
    }
    
    return query;
  }

  // Generate related searches
  static List<String> _generateRelatedSearches(String query) {
    if (query.isEmpty) return [];
    
    final related = <String>[];
    
    // Add trending tags that relate to query
    for (final tag in _trendingTags) {
      if (tag.contains(query.toLowerCase()) || 
          query.toLowerCase().contains(tag)) {
        related.add(tag.replaceAll('_', ' '));
      }
    }
    
    // Add category-based suggestions
    for (final category in CringeCategory.values) {
      if (category.displayName.toLowerCase().contains(query.toLowerCase())) {
        related.add(category.displayName);
      }
    }
    
    // Limit to 5 suggestions
    return related.take(5).toList();
  }

  // Get recent searches
  static List<String> getRecentSearches() {
    return List.from(_recentSearches);
  }

  // Get trending tags
  static List<String> getTrendingTags() {
    return List.from(_trendingTags);
  }

  // Clear search history
  static void clearSearchHistory() {
    _recentSearches.clear();
  }

  // Get search suggestions based on partial query
  static List<String> getSuggestions(String partialQuery) {
    if (partialQuery.isEmpty) {
      return getTrendingTags().take(8).toList();
    }
    
    final suggestions = <String>{};
    
    // Add from recent searches
    for (final search in _recentSearches) {
      if (search.toLowerCase().contains(partialQuery.toLowerCase())) {
        suggestions.add(search);
      }
    }
    
    // Add from trending tags
    for (final tag in _trendingTags) {
      if (tag.toLowerCase().contains(partialQuery.toLowerCase())) {
        suggestions.add(tag.replaceAll('_', ' '));
      }
    }
    
    // Add from entry titles and tags
    for (final entry in _allEntries.take(20)) {
      if (entry.baslik.toLowerCase().contains(partialQuery.toLowerCase())) {
        suggestions.add(entry.baslik);
      }
      
      for (final tag in entry.etiketler) {
        if (tag.toLowerCase().contains(partialQuery.toLowerCase())) {
          suggestions.add(tag);
        }
      }
    }
    
    return suggestions.take(8).toList();
  }

  // Get popular searches
  static List<String> getPopularSearches() {
    return [
      'okul utancı',
      'aşk acısı',
      'iş görüşmesi',
      'sosyal medya fail',
      'zoom toplantısı',
      'aile yemeği',
      'crush drama',
      'epic fail',
    ];
  }
}
