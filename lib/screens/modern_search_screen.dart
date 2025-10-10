import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../services/user_search_service.dart';
import '../widgets/cringe_default_background.dart';
import '../widgets/search/user_search_tile.dart';
import 'simple_profile_screen.dart';

class ModernSearchScreen extends StatefulWidget {
  const ModernSearchScreen({super.key});

  @override
  State<ModernSearchScreen> createState() => _ModernSearchScreenState();
}

class _ModernSearchScreenState extends State<ModernSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingSuggestions = false;

  List<User> _results = const [];
  List<User> _popularUsers = const [];
  List<User> _followingPreview = const [];

  String _query = '';
  bool _hasMore = false;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final popularFuture = UserSearchService.instance.fetchPopularUsers(
        limit: 12,
      );
      final followingFuture = UserSearchService.instance.fetchFollowingPreview(
        limit: 12,
      );

      final popular = await popularFuture;
      final following = await followingFuture;

      if (!mounted) return;
      setState(() {
        _popularUsers = popular;
        _followingPreview = following;
        _isLoadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = false);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();

    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _query = '';
        _results = const [];
        _cursor = null;
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _query = query;
    });

    try {
      final page = await UserSearchService.instance.searchByUsernamePrefix(
        query: query,
        limit: 30,
      );

      if (!mounted) return;
      setState(() {
        _results = page.users;
        _cursor = page.lastDocument;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _cursor == null) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final page = await UserSearchService.instance.searchByUsernamePrefix(
        query: _query,
        limit: 30,
        startAfter: _cursor,
      );

      if (!mounted) return;

      final existingIds = _results.map((user) => user.id).toSet();
      final merged = <User>[..._results];
      for (final user in page.users) {
        if (existingIds.add(user.id)) {
          merged.add(user);
        }
      }

      setState(() {
        _results = merged;
        _cursor = page.lastDocument;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
    _runSearch('');
  }

  void _openUserProfile(User user) {
    HapticFeedback.selectionClick();
    final normalizedId = user.id.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SimpleProfileScreen(
          userId: normalizedId.isNotEmpty ? normalizedId : null,
          initialUser: user,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      titleSpacing: 0,
      backgroundColor: Colors.black,
      title: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Kullanıcı ara...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            prefixIcon: const Icon(Icons.search, color: Colors.white, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: _clearSearch,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                : null,
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
          onSubmitted: _runSearch,
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return _buildSuggestionBody();
    }

    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Eşleşen kullanıcı bulunamadı.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return _buildLoadMoreTile();
        }

        final user = _results[index];
        return UserSearchTile(
          user: user,
          onTap: () => _openUserProfile(user),
          onFollow: () => _openUserProfile(user),
        );
      },
    );
  }

  Widget _buildLoadMoreTile() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Align(
      alignment: Alignment.center,
      child: OutlinedButton.icon(
        onPressed: _loadMore,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        icon: const Icon(Icons.expand_more),
        label: const Text('Daha fazla yükle'),
      ),
    );
  }

  Widget _buildSuggestionBody() {
    if (_isLoadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }

    final sections = <Widget>[];

    void addSection(String title, List<User> source) {
      final unique = <User>[];
      final seen = <String>{};
      for (final user in source) {
        if (user.id.trim().isEmpty) continue;
        if (seen.add(user.id)) {
          unique.add(user);
        }
      }
      if (unique.isEmpty) return;
      sections
        ..add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        ..addAll(
          unique.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UserSearchTile(
                user: user,
                onTap: () => _openUserProfile(user),
                onFollow: () => _openUserProfile(user),
              ),
            ),
          ),
        )
        ..add(const SizedBox(height: 24));
    }

    addSection('Takip Ettiklerin', _followingPreview);
    addSection('Şu An Popüler', _popularUsers);

    if (sections.isEmpty) {
      return const Center(
        child: Text(
          'Kişi önerisi bulunmuyor. Aramak için yukarıdaki alanı kullan.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: sections,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: CringeDefaultBackground(
        bubbleCount: 25,
        bubbleColor: const Color(0xFF888888),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }
}
