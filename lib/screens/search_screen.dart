import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cringe_search_service.dart';
import '../models/cringe_entry.dart';
import '../widgets/cringe_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  SearchResult? _searchResult;
  SearchFilter _currentFilter = SearchFilter();
  SearchSortBy _currentSort = SearchSortBy.relevance;
  bool _isLoading = false;
  bool _showFilters = false;
  bool _showSearchSuggestions = false;
  List<String> _currentSuggestions = [];

  late AnimationController _filterAnimationController;
  late Animation<double> _filterSlideAnimation;
  late AnimationController _loadingAnimationController;

  @override
  void initState() {
    super.initState();
    _initializeSearch();
    _setupAnimations();
    _setupSearchController();
  }

  void _setupAnimations() {
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _filterSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _filterAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  void _setupSearchController() {
    _searchController.addListener(() {
      if (_searchController.text.isNotEmpty) {
        _updateSuggestions(_searchController.text);
        if (!_showSearchSuggestions) {
          setState(() {
            _showSearchSuggestions = true;
          });
        }
      } else {
        _loadPopularSearches();
      }
    });

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _loadPopularSearches();
        setState(() {
          _showSearchSuggestions = true;
        });
      }
    });
  }

  Future<void> _initializeSearch() async {
    await CringeSearchService.initialize();
    _loadPopularSearches();
  }

  void _loadPopularSearches() {
    setState(() {
      _currentSuggestions = CringeSearchService.getPopularSearches();
      _showSearchSuggestions = true;
    });
  }

  void _updateSuggestions(String query) {
    setState(() {
      _currentSuggestions = CringeSearchService.getSuggestions(query);
    });
  }

  Future<void> _performSearch({String? customQuery}) async {
    final query = customQuery ?? _searchController.text;
    if (query.isEmpty && _currentFilter.isEmpty) return;

    setState(() {
      _isLoading = true;
      _showSearchSuggestions = false;
    });

    _loadingAnimationController.repeat();

    try {
      final result = await CringeSearchService.search(
        query: query,
        filter: _currentFilter,
        sortBy: _currentSort,
      );

      setState(() {
        _searchResult = result;
        _isLoading = false;
        if (customQuery != null) {
          _searchController.text = customQuery;
        }
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _loadingAnimationController.stop();
    }
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });

    if (_showFilters) {
      _filterAnimationController.forward();
    } else {
      _filterAnimationController.reverse();
    }

    HapticFeedback.selectionClick();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResult = null;
      _currentFilter = SearchFilter();
      _showSearchSuggestions = false;
    });

    HapticFeedback.selectionClick();
  }

  void _onSuggestionTap(String suggestion) {
    _performSearch(customQuery: suggestion);
    _searchFocusNode.unfocus();
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSortBottomSheet(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _filterAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            if (_showFilters) _buildFiltersSection(),
            if (_showSearchSuggestions)
              _buildSuggestionsSection()
            else
              _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A237E).withValues(alpha: 0.9),
            const Color(0xFF3F51B5).withValues(alpha: 0.7),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '🔍 Krep Avcısı',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFilters,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
          if (_searchResult != null) _buildSearchStats(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Krep avcılığına başla...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        onPressed: _clearSearch,
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      onPressed: () => _performSearch(),
                    ),
                  ],
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
        onSubmitted: (value) => _performSearch(),
      ),
    );
  }

  Widget _buildSearchStats() {
    if (_searchResult == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(
            '${_searchResult!.totalCount} sonuç',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            ' • ${_searchResult!.searchDuration.inMilliseconds}ms',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          if (_searchResult!.totalCount > 0)
            GestureDetector(
              onTap: _showSortBottomSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sort,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentSort.displayName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: const Offset(0, 0),
      ).animate(_filterSlideAnimation),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF1A237E).withValues(alpha: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtreler',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildCategoryFilter(),
            const SizedBox(height: 16),
            _buildKrepLevelFilter(),
            const SizedBox(height: 16),
            _buildDateFilter(),
            const SizedBox(height: 16),
            _buildOtherFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategoriler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CringeCategory.values.map((category) {
            final isSelected = _currentFilter.categories.contains(category);
            return GestureDetector(
              onTap: () {
                setState(() {
                  final newCategories = Set<CringeCategory>.from(
                    _currentFilter.categories,
                  );
                  if (isSelected) {
                    newCategories.remove(category);
                  } else {
                    newCategories.add(category);
                  }
                  _currentFilter = _currentFilter.copyWith(
                    categories: newCategories,
                  );
                });
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.purple.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.purple
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${category.emoji} ${category.displayName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKrepLevelFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Krep Seviyesi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(
            _currentFilter.minKrepLevel ?? 1.0,
            _currentFilter.maxKrepLevel ?? 10.0,
          ),
          min: 1.0,
          max: 10.0,
          divisions: 9,
          labels: RangeLabels(
            (_currentFilter.minKrepLevel ?? 1.0).toStringAsFixed(0),
            (_currentFilter.maxKrepLevel ?? 10.0).toStringAsFixed(0),
          ),
          activeColor: Colors.purple,
          inactiveColor: Colors.white.withValues(alpha: 0.3),
          onChanged: (RangeValues values) {
            setState(() {
              _currentFilter = _currentFilter.copyWith(
                minKrepLevel: values.start,
                maxKrepLevel: values.end,
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tarih Aralığı',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDateButton('Başlangıç', _currentFilter.startDate, (
                date,
              ) {
                setState(() {
                  _currentFilter = _currentFilter.copyWith(startDate: date);
                });
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateButton('Bitiş', _currentFilter.endDate, (date) {
                setState(() {
                  _currentFilter = _currentFilter.copyWith(endDate: date);
                });
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateButton(
    String label,
    DateTime? date,
    Function(DateTime?) onDateChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        onDateChanged(selectedDate);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date != null ? '${date.day}/${date.month}/${date.year}' : 'Seç',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Diğer Filtreler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildToggleFilter(
              'Sadece Anonim',
              _currentFilter.onlyAnonymous ?? false,
              (value) {
                setState(() {
                  _currentFilter = _currentFilter.copyWith(
                    onlyAnonymous: value,
                  );
                });
              },
            ),
            _buildToggleFilter(
              'Sadece Premium',
              _currentFilter.onlyPremium ?? false,
              (value) {
                setState(() {
                  _currentFilter = _currentFilter.copyWith(onlyPremium: value);
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleFilter(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          activeThumbColor: Colors.purple,
          inactiveThumbColor: Colors.white.withValues(alpha: 0.7),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
          onChanged: onChanged,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsSection() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _searchController.text.isEmpty
                      ? 'Popüler Aramalar'
                      : 'Öneriler',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _currentSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _currentSuggestions[index];
                  return GestureDetector(
                    onTap: () => _onSuggestionTap(suggestion),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _searchController.text.isEmpty
                                ? Icons.trending_up
                                : Icons.search,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Krep avında...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResult == null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Arama yapmak için yukarıdaki çubuğu kullan',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResult!.entries.isEmpty) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Hiç sonuç bulunamadı',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Farklı kelimeler veya filtreler deneyebilirsin',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchResult!.aiSuggestion != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purple.withValues(alpha: 0.3),
                        Colors.blue.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: Colors.purple.shade300,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI Önerisi',
                            style: TextStyle(
                              color: Colors.purple.shade300,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchResult!.aiSuggestion!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResult!.entries.length,
        itemBuilder: (context, index) {
          final entry = _searchResult!.entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CringeCard(entry: entry),
          );
        },
      ),
    );
  }

  Widget _buildSortBottomSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Sıralama',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          ...SearchSortBy.values.map((sortBy) {
            final isSelected = _currentSort == sortBy;
            return ListTile(
              leading: Icon(
                _getSortIcon(sortBy),
                color: isSelected
                    ? Colors.purple
                    : Colors.white.withValues(alpha: 0.7),
              ),
              title: Text(
                sortBy.displayName,
                style: TextStyle(
                  color: isSelected
                      ? Colors.purple
                      : Colors.white.withValues(alpha: 0.9),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: Colors.purple)
                  : null,
              onTap: () {
                setState(() {
                  _currentSort = sortBy;
                });
                Navigator.pop(context);
                _performSearch();
              },
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _getSortIcon(SearchSortBy sortBy) {
    switch (sortBy) {
      case SearchSortBy.relevance:
        return Icons.star;
      case SearchSortBy.newest:
        return Icons.new_releases;
      case SearchSortBy.oldest:
        return Icons.history;
      case SearchSortBy.highestKrep:
        return Icons.trending_up;
      case SearchSortBy.lowestKrep:
        return Icons.trending_down;
      case SearchSortBy.mostLiked:
        return Icons.favorite;
      case SearchSortBy.mostCommented:
        return Icons.comment;
    }
  }
}
