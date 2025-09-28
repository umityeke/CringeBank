import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cringe_entry_service.dart';
import '../services/cringe_search_service.dart';
import '../models/cringe_entry.dart';
import '../models/user_model.dart';
import '../widgets/entry_comments_sheet.dart';
import '../widgets/modern_cringe_card.dart';
import '../widgets/animated_bubble_background.dart';
import '../widgets/search/user_search_tile.dart';
import 'simple_profile_screen.dart';

enum SearchResultView { entries, users, all }

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
  UserSearchResult? _userSearchResult;
  SearchFilter _currentFilter = SearchFilter();
  final SearchSortBy _currentSort = SearchSortBy.newest;
  SearchResultView _currentView = SearchResultView.entries;
  bool _isLoading = false;
  bool _showFilters = false;
  bool _showSearchSuggestions = false;
  List<String> _currentSuggestions = [];
  final Set<String> _locallyLikedEntryIds = <String>{};

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
        _userSearchResult = null;
        _currentView = SearchResultView.entries;
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
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF121B2E), Color(0xFF090C14)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.pinkAccent.withOpacity(0.12),
                ),
              ),
            ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _buildResultViewSwitcher(),
          ),
          Expanded(child: _buildResultArea()),
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
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: const Text(
                          'Filtreler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white, size: 18),
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

  Widget _buildResultArea() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    final hasEntries = _searchResult?.entries.isNotEmpty ?? false;
    final hasUsers = _userSearchResult?.users.isNotEmpty ?? false;

    if (!hasEntries && !hasUsers) {
      return _buildEmptyState();
    }

    switch (_currentView) {
      case SearchResultView.entries:
        return hasEntries ? _buildEntriesList() : _buildEmptyState();
      case SearchResultView.users:
        return hasUsers ? _buildUsersList() : _buildEmptyState();
      case SearchResultView.all:
        return _buildCombinedResults(
          showEntries: hasEntries,
          showUsers: hasUsers,
        );
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    switch (_currentView) {
      case SearchResultView.entries:
        message = 'Bu arama için krep bulunamadı.';
        break;
      case SearchResultView.users:
        message = 'Uyumlu kullanıcı bulunamadı.';
        break;
      case SearchResultView.all:
        message = 'Bu arama için sonuç bulunamadı.';
        break;
    }

    return Center(
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEntriesList() {
    final entries = _searchResult?.entries ?? const <CringeEntry>[];
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ModernCringeCard(
            entry: entry,
            onTap: () => _openCringeDetail(entry),
            onLike: () => _likeCringe(entry),
            onComment: () => _commentCringe(entry),
            onShare: () => _shareCringe(entry),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    final users = _userSearchResult?.users ?? const <User>[];
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: UserSearchTile(
            user: user,
            onTap: () => _openUserProfile(user),
            onFollow: () => _openUserProfile(user),
          ),
        );
      },
    );
  }

  Widget _buildCombinedResults({
    required bool showEntries,
    required bool showUsers,
  }) {
    final entryList = showEntries
        ? (_searchResult?.entries ?? const <CringeEntry>[])
        : const <CringeEntry>[];
    final userList = showUsers
        ? (_userSearchResult?.users ?? const <User>[])
        : const <User>[];

    final entryPreview = entryList.length > 10
        ? entryList.take(10).toList()
        : entryList;
    final userPreview = userList.length > 6
        ? userList.take(6).toList()
        : userList;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      children: [
        if (showUsers && userPreview.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Kullanıcılar',
            count: userPreview.length,
            totalCount: _userSearchResult?.totalCount,
          ),
          const SizedBox(height: 12),
          ...userPreview.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: UserSearchTile(
                user: user,
                onTap: () => _openUserProfile(user),
                onFollow: () => _openUserProfile(user),
              ),
            ),
          ),
          if (_userSearchResult != null &&
              _userSearchResult!.totalCount > userPreview.length)
            _buildSeeAllButton(SearchResultView.users),
          if (showEntries && entryPreview.isNotEmpty)
            const SizedBox(height: 24),
        ],
        if (showEntries && entryPreview.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Krepler',
            count: entryPreview.length,
            totalCount: _searchResult?.totalCount,
          ),
          const SizedBox(height: 12),
          ...entryPreview.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ModernCringeCard(
                entry: entry,
                onTap: () => _openCringeDetail(entry),
                onLike: () => _likeCringe(entry),
                onComment: () => _commentCringe(entry),
                onShare: () => _shareCringe(entry),
              ),
            ),
          ),
          if (_searchResult != null &&
              _searchResult!.totalCount > entryPreview.length)
            _buildSeeAllButton(SearchResultView.entries),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    int? totalCount,
  }) {
    final totalLabel = totalCount != null && totalCount > count
        ? 'Tümü: $totalCount'
        : 'Toplam: $count';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          totalLabel,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSeeAllButton(SearchResultView target) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          setState(() => _currentView = target);
        },
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        child: const Text('Tümünü gör'),
      ),
    );
  }

  Widget _buildResultViewSwitcher() {
    final hasEntries = _searchResult?.entries.isNotEmpty ?? false;
    final hasUsers = _userSearchResult?.users.isNotEmpty ?? false;
    final totalCombined =
        (_searchResult?.totalCount ?? 0) + (_userSearchResult?.totalCount ?? 0);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        ChoiceChip(
          showCheckmark: false,
          label: Text('Krepler (${_searchResult?.totalCount ?? 0})'),
          selected: _currentView == SearchResultView.entries,
          onSelected: hasEntries
              ? (selected) {
                  if (selected) {
                    setState(() => _currentView = SearchResultView.entries);
                  }
                }
              : null,
          backgroundColor: Colors.white.withOpacity(0.08),
          selectedColor: Colors.white.withOpacity(0.2),
          labelStyle: const TextStyle(color: Colors.white),
        ),
        ChoiceChip(
          showCheckmark: false,
          label: Text('Kullanıcılar (${_userSearchResult?.totalCount ?? 0})'),
          selected: _currentView == SearchResultView.users,
          onSelected: hasUsers
              ? (selected) {
                  if (selected) {
                    setState(() => _currentView = SearchResultView.users);
                  }
                }
              : null,
          backgroundColor: Colors.white.withOpacity(0.08),
          selectedColor: Colors.white.withOpacity(0.2),
          labelStyle: const TextStyle(color: Colors.white),
        ),
        ChoiceChip(
          showCheckmark: false,
          label: Text('Hepsi ($totalCombined)'),
          selected: _currentView == SearchResultView.all,
          onSelected: (hasEntries && hasUsers)
              ? (selected) {
                  if (selected) {
                    setState(() => _currentView = SearchResultView.all);
                  }
                }
              : null,
          backgroundColor: Colors.white.withOpacity(0.08),
          selectedColor: Colors.white.withOpacity(0.2),
          labelStyle: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showSearchSuggestions = false;
      _userSearchResult = null;
      _searchResult = null;
      _currentView = SearchResultView.entries;
    });
    _initializeSearch();
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

  Future<void> _performSearch(String query) async {
    final formattedQuery = query.trim();
    if (formattedQuery.isEmpty) return;

    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    setState(() {
      _isLoading = true;
      _showSearchSuggestions = false;
    });

    try {
      final results = await Future.wait([
        CringeSearchService.search(
          query: formattedQuery,
          filter: _currentFilter,
          sortBy: _currentSort,
        ),
        CringeSearchService.searchUsers(query: formattedQuery),
      ]);

      if (!mounted) return;

      final entryResult = results[0] as SearchResult;
      final userResult = results[1] as UserSearchResult;

      final hasEntries = entryResult.entries.isNotEmpty;
      final hasUsers = userResult.users.isNotEmpty;
      final nextView = hasEntries && hasUsers
          ? SearchResultView.all
          : hasUsers
          ? SearchResultView.users
          : SearchResultView.entries;

      setState(() {
        _searchResult = entryResult;
        _userSearchResult = userResult;
        _currentView = nextView;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openUserProfile(User user) {
    HapticFeedback.selectionClick();
    final normalizedId = user.id.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleProfileScreen(
          userId: normalizedId.isNotEmpty ? normalizedId : null,
          initialUser: user,
        ),
      ),
    );
  }

  void _showSuggestions() {
    // Simulated suggestions - now empty since we removed trending searches
    setState(() {
      _currentSuggestions = [];
      _showSearchSuggestions = false;
    });
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion
        .replaceAll(RegExp(r'[🔥💔😅🤡📱🍻]'), '')
        .trim();
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

  void _likeCringe(CringeEntry entry) async {
    if (_locallyLikedEntryIds.contains(entry.id)) {
      return;
    }

    HapticFeedback.lightImpact();

    try {
      final success = await CringeEntryService.instance.likeEntry(entry.id);

      if (!mounted) return;

      if (!success) {
        throw Exception('like-failed');
      }

      setState(() {
        _locallyLikedEntryIds.add(entry.id);
        _searchResult = _mapSearchResultEntry(
          entryId: entry.id,
          mapper: (current) => current.copyWith(
            begeniSayisi: current.begeniSayisi + 1,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beğeni kaydedilemedi. Tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _commentCringe(CringeEntry entry) {
    HapticFeedback.selectionClick();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntryCommentsSheet(
        entry: entry,
        onCommentAdded: () {
          if (!mounted) return;
          setState(() {
            _searchResult = _mapSearchResultEntry(
              entryId: entry.id,
              mapper: (current) => current.copyWith(
                yorumSayisi: current.yorumSayisi + 1,
              ),
            );
          });
        },
      ),
    );
  }

  void _shareCringe(CringeEntry entry) {
    HapticFeedback.mediumImpact();
    // Handle share
  }

  SearchResult? _mapSearchResultEntry({
    required String entryId,
    required CringeEntry Function(CringeEntry current) mapper,
  }) {
    final currentResult = _searchResult;
    if (currentResult == null) return null;

    final updatedEntries = currentResult.entries
        .map((item) => item.id == entryId ? mapper(item) : item)
        .toList(growable: false);

    return SearchResult(
      entries: updatedEntries,
      totalCount: currentResult.totalCount,
      aiSuggestion: currentResult.aiSuggestion,
      relatedSearches: List<String>.from(currentResult.relatedSearches),
      categoryDistribution:
          Map<CringeCategory, int>.from(currentResult.categoryDistribution),
      searchDuration: currentResult.searchDuration,
    );
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
