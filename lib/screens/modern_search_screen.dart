import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cringe_search_service.dart';
import '../models/cringe_entry.dart';
import '../widgets/modern_cringe_card.dart';
import '../widgets/animated_bubble_background.dart';

class ModernSearchScreen extends StatefulWidget {
  const ModernSearchScreen({super.key});

  @override
  State<ModernSearchScreen> createState() => _ModernSearchScreenState();
}

class _ModernSearchScreenState extends State<ModernSearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  SearchResult? _searchResult;
  SearchFilter _currentFilter = SearchFilter();
  final SearchSortBy _currentSort = SearchSortBy.newest;
  bool _isLoading = false;
  bool _showFilters = false;
  bool _showSearchSuggestions = false;
  List<String> _currentSuggestions = [];

  late AnimationController _backgroundController;
  late AnimationController _searchBarController;
  late AnimationController _filterController;
  late Animation<double> _searchBarAnimation;
  late Animation<double> _filterAnimation;

  @override
  void initState() {
    super.initState();
    _initializeSearch();
    _setupAnimations();
    _setupSearchController();
  }

  void _initializeSearch() async {
    setState(() => _isLoading = true);
    try {
      final result = await CringeSearchService.search(
        query: '',
        filter: _currentFilter,
        sortBy: _currentSort,
      );
      setState(() {
        _searchResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _setupAnimations() {
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _searchBarController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _filterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _searchBarAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _searchBarController, curve: Curves.elasticOut),
    );

    _filterAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _filterController, curve: Curves.easeInOut),
    );

    _searchBarController.forward();
  }

  void _setupSearchController() {
    _searchController.addListener(() {
      if (_searchController.text.isNotEmpty) {
        _showSuggestions();
      } else {
        setState(() => _showSearchSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _searchBarController.dispose();
    _filterController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      body: AnimatedBubbleBackground(
        bubbleCount: 35,
        bubbleColor: const Color(0xFF888888),
        child: Stack(
          children: [
            _buildContent(),
            if (_showSearchSuggestions) _buildSearchSuggestions(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ),
      ),
      title: _buildSearchBar(),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _searchBarAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _searchBarAnimation.value,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Krep ara...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 24,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: _clearSearch,
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white,
                              size: 20,
                            ),
                          )
                        : IconButton(
                            onPressed: _toggleFilters,
                            icon: const Icon(
                              Icons.tune,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 80), // AppBar space
          if (_showFilters) _buildFilterPanel(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _searchResult == null || _searchResult!.entries.isEmpty
                    ? _buildEmptyState()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return AnimatedBuilder(
      animation: _filterAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - _filterAnimation.value)),
          child: Opacity(
            opacity: _filterAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtreler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCategoryFilter(),
                      const SizedBox(height: 16),
                      _buildCringeRangeFilter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CringeCategory.values.map((category) {
            final isSelected = _currentFilter.categories.contains(category);
            return GestureDetector(
              onTap: () => _selectCategory(category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0.2),
                          ],
                        )
                      : null,
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withOpacity(0.6)
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  category.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
          color: isSelected
            ? Colors.white
            : Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCringeRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Krep Seviyesi: ${(_currentFilter.minKrepLevel ?? 1.0).toStringAsFixed(0)} - ${(_currentFilter.maxKrepLevel ?? 10.0).toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
          ),
          child: RangeSlider(
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
            onChanged: (RangeValues values) {
              setState(() {
                _currentFilter = _currentFilter.copyWith(
                  minKrepLevel: values.start,
                  maxKrepLevel: values.end,
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSuggestions() {
    return Positioned(
      top: 140,
      left: 20,
      right: 20,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.3),
              Colors.white.withOpacity(0.1),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: _currentSuggestions.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _selectSuggestion(_currentSuggestions[index]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _currentSuggestions[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox.shrink();
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResult!.entries.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ModernCringeCard(
            entry: _searchResult!.entries[index],
            onTap: () => _openCringeDetail(_searchResult!.entries[index]),
            onLike: () => _likeCringe(_searchResult!.entries[index]),
            onComment: () => _commentCringe(_searchResult!.entries[index]),
            onShare: () => _shareCringe(_searchResult!.entries[index]),
          ),
        );
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _showSearchSuggestions = false);
  }

  void _toggleFilters() {
    HapticFeedback.lightImpact();
    setState(() => _showFilters = !_showFilters);
    if (_showFilters) {
      _filterController.forward();
    } else {
      _filterController.reverse();
    }
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    setState(() {
      _isLoading = true;
      _showSearchSuggestions = false;
    });

    try {
      final result = await CringeSearchService.search(
        query: query,
        filter: _currentFilter,
        sortBy: _currentSort,
      );
      setState(() {
        _searchResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showSuggestions() {
    // Simulated suggestions - now empty since we removed trending searches
    setState(() {
      _currentSuggestions = [];
      _showSearchSuggestions = false;
    });
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion.replaceAll(RegExp(r'[🔥💔😅🤡📱🍻]'), '').trim();
    _performSearch(_searchController.text);
  }

  void _selectCategory(CringeCategory category) {
    setState(() {
      final newCategories = Set<CringeCategory>.from(_currentFilter.categories);
      if (newCategories.contains(category)) {
        newCategories.remove(category);
      } else {
        newCategories.add(category);
      }
      _currentFilter = _currentFilter.copyWith(categories: newCategories);
    });
  }

  void _openCringeDetail(CringeEntry entry) {
    HapticFeedback.selectionClick();
    // Navigate to detail screen
  }

  void _likeCringe(CringeEntry entry) {
    HapticFeedback.lightImpact();
    // Handle like
  }

  void _commentCringe(CringeEntry entry) {
    HapticFeedback.selectionClick();
    // Handle comment
  }

  void _shareCringe(CringeEntry entry) {
    HapticFeedback.mediumImpact();
    // Handle share
  }
}

class SearchBubblesPainter extends CustomPainter {
  final double animationValue;
  
  SearchBubblesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    // Animated search icons
    for (int i = 0; i < 15; i++) {
      final offset = Offset(
        (size.width * 0.15 * i + animationValue * 40) % size.width,
        (size.height * 0.12 * i + animationValue * 25) % size.height,
      );
      final radius = 15.0 + (i % 4) * 5.0;
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(SearchBubblesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}