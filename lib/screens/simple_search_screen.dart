import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/cringe_search_service.dart';
import '../services/search_history_service.dart';
import '../services/user_service.dart';
import 'simple_profile_screen.dart';

class SimpleSearchScreen extends StatefulWidget {
  const SimpleSearchScreen({super.key});

  @override
  State<SimpleSearchScreen> createState() => _SimpleSearchScreenState();
}

class _SimpleSearchScreenState extends State<SimpleSearchScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 300);
  static const _maxHistoryEntries = 20;
  static const _maxFeaturedUsers = 12;
  static const _searchResultLimit = 40;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<User> _featuredUsers = <User>[];
  List<User> _searchResults = <User>[];
  List<Map<String, dynamic>> _searchHistory = <Map<String, dynamic>>[];

  bool _isLoading = true;
  bool _isSearchActive = false;
  bool _isSearchBusy = false;

  Timer? _debounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchTextChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_handleSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final history = await SearchHistoryService.getHistory();
      final users = await UserService.instance.getAllUsers();
      if (!mounted) return;

      final currentUserId = UserService.instance.currentUser?.id;

      setState(() {
        _searchHistory = history
            .where((item) => item['id'] != currentUserId)
            .take(_maxHistoryEntries)
            .toList();
        _featuredUsers = users
            .where((user) => user.id != currentUserId)
            .take(_maxFeaturedUsers)
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Veriler yüklenemedi: $error')));
    }
  }

  void _handleSearchTextChanged() {
    final query = _searchController.text.trim();

    _debounce?.cancel();

    if (query.isEmpty) {
      _resetSearchState();
      return;
    }

    _debounce = Timer(_searchDebounceDuration, () {
      _performSearch(query);
    });
  }

  void _resetSearchState() {
    _searchRequestId++;
    if (!_isSearchActive && _searchResults.isEmpty) {
      return;
    }

    setState(() {
      _isSearchActive = false;
      _isSearchBusy = false;
      _searchResults = <User>[];
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _resetSearchState();
      return;
    }

    final requestId = ++_searchRequestId;

    setState(() {
      _isSearchActive = true;
      _isSearchBusy = true;
    });

    try {
      final result = await CringeSearchService.searchUsers(
        query: trimmedQuery,
        limit: _searchResultLimit,
      );

      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      final currentUserId = UserService.instance.currentUser?.id;
      final filteredUsers = result.users
          .where((user) => user.id != currentUserId)
          .toList(growable: false);

      setState(() {
        _searchResults = filteredUsers;
        _isSearchBusy = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() => _isSearchBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Arama yapılamadı: $error')));
    }
  }

  Future<void> _refreshHistory() async {
    final history = await SearchHistoryService.getHistory();
    if (!mounted) return;

    final currentUserId = UserService.instance.currentUser?.id;
    setState(() {
      _searchHistory = history
          .where((item) => item['id'] != currentUserId)
          .take(_maxHistoryEntries)
          .toList();
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geçmişi Temizle'),
        content: const Text(
          'Tüm arama geçmişini silmek istediğinden emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SearchHistoryService.clearHistory();
      await _refreshHistory();
    }
  }

  Future<void> _handleUserTap(User user) async {
    await SearchHistoryService.addToHistory(user);
    await _refreshHistory();

    if (!mounted) return;
    _searchFocusNode.unfocus();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            SimpleProfileScreen(userId: user.id, initialUser: user),
      ),
    );
  }

  Future<void> _handleHistoryTap(Map<String, dynamic> historyItem) async {
    final userId = historyItem['id'] as String?;
    if (userId == null || userId.isEmpty) {
      return;
    }

    final user = await UserService.instance.getUserById(userId);
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı artık mevcut değil.')),
        );
      }
      await _refreshHistory();
      return;
    }

    await _handleUserTap(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Ara')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: 'Kullanıcı ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _resetSearchState();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade900
                    : Colors.grey.shade100,
              ),
            ),
          ),
          if (_isSearchActive && _isSearchBusy)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearchActive
                ? _buildSearchResults()
                : _buildInitialContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearchBusy && _searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text(
              'Kullanıcı bulunamadı',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildInitialContent() {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (_searchHistory.isNotEmpty) ...[
            _buildSectionHeader('Son Aramalar', showClearButton: true),
            ..._searchHistory.map(_buildHistoryTile),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('Öne Çıkan Kullanıcılar'),
          if (_featuredUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Henüz öne çıkan kullanıcı yok.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ..._featuredUsers.map(_buildUserTile),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool showClearButton = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (showClearButton)
            TextButton.icon(
              onPressed: _clearHistory,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Temizle'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> historyItem) {
    final displayName = historyItem['displayName'] as String? ?? 'Anonim';
    final username = historyItem['username'] as String? ?? 'kullanici';
    final krepScore = historyItem['krepScore'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _buildAvatarCircle(
          avatar: (historyItem['avatar'] as String?) ?? '',
          fallbackLabel: _initialForHistory(historyItem),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
        ),
        title: Text(displayName),
        subtitle: Text('@$username'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('$krepScore'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _handleHistoryTap(historyItem),
      ),
    );
  }

  Widget _buildUserTile(User user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _buildAvatarCircle(
          avatar: user.avatar,
          fallbackLabel: _initialForUser(user),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
        ),
        title: Text(user.displayName),
        subtitle: Text('@${user.username}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('${user.krepScore}'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _handleUserTap(user),
      ),
    );
  }

  String _initialForUser(User user) {
    final avatarInitial = _firstVisibleCharacter(user.avatar);
    if (avatarInitial != null && avatarInitial.isNotEmpty) {
      return avatarInitial;
    }

    final displayInitial = _firstVisibleCharacter(
      user.displayName,
      uppercase: true,
    );
    if (displayInitial != null && displayInitial.isNotEmpty) {
      return displayInitial;
    }

    final usernameInitial = _firstVisibleCharacter(
      user.username.replaceAll('@', ''),
      uppercase: true,
    );
    if (usernameInitial != null && usernameInitial.isNotEmpty) {
      return usernameInitial;
    }

    return '👤';
  }

  String _initialForHistory(Map<String, dynamic> item) {
    final avatarInitial = _firstVisibleCharacter(
      item['avatar'] as String? ?? '',
    );
    if (avatarInitial != null && avatarInitial.isNotEmpty) {
      return avatarInitial;
    }

    final displayInitial = _firstVisibleCharacter(
      item['displayName'] as String? ?? '',
      uppercase: true,
    );
    if (displayInitial != null && displayInitial.isNotEmpty) {
      return displayInitial;
    }

    final usernameInitial = _firstVisibleCharacter(
      (item['username'] as String? ?? '').replaceAll('@', ''),
      uppercase: true,
    );
    if (usernameInitial != null && usernameInitial.isNotEmpty) {
      return usernameInitial;
    }

    return '👤';
  }

  String? _firstVisibleCharacter(String value, {bool uppercase = false}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final iterator = trimmed.runes.iterator;
    if (!iterator.moveNext()) {
      return null;
    }

    final buffer = StringBuffer();
    buffer.writeCharCode(iterator.current);

    while (true) {
      final hasNext = iterator.moveNext();
      if (!hasNext) {
        break;
      }

      final codePoint = iterator.current;
      if (codePoint == 0x200D) {
        buffer.writeCharCode(codePoint);
        if (iterator.moveNext()) {
          buffer.writeCharCode(iterator.current);
        }
        continue;
      }

      if (_isCombiningMark(codePoint)) {
        buffer.writeCharCode(codePoint);
        continue;
      }

      break;
    }

    final result = buffer.toString();
    return uppercase ? result.toUpperCase() : result;
  }

  bool _isCombiningMark(int codePoint) {
    return (codePoint >= 0x0300 && codePoint <= 0x036F) ||
        (codePoint >= 0x1AB0 && codePoint <= 0x1AFF) ||
        (codePoint >= 0x1DC0 && codePoint <= 0x1DFF) ||
        (codePoint >= 0x20D0 && codePoint <= 0x20FF) ||
        (codePoint >= 0xFE20 && codePoint <= 0xFE2F);
  }

  Widget _buildAvatarCircle({
    required String avatar,
    required String fallbackLabel,
    required Color backgroundColor,
  }) {
    final trimmed = avatar.trim();
    final provider = _resolveImageProvider(trimmed);

    if (provider != null) {
      return CircleAvatar(
        backgroundImage: provider,
        backgroundColor: backgroundColor,
      );
    }

    if (trimmed.isNotEmpty && trimmed.length <= 3) {
      return CircleAvatar(
        backgroundColor: backgroundColor,
        child: Text(trimmed, style: const TextStyle(fontSize: 20)),
      );
    }

    return CircleAvatar(
      backgroundColor: backgroundColor,
      child: Text(fallbackLabel, style: const TextStyle(fontSize: 20)),
    );
  }

  ImageProvider? _resolveImageProvider(String value) {
    if (value.startsWith('http')) {
      return CachedNetworkImageProvider(value);
    }

    if (value.startsWith('data:image')) {
      final bytes = _decodeDataUri(value);
      if (bytes != null) {
        return MemoryImage(bytes);
      }
    }

    return null;
  }

  Uint8List? _decodeDataUri(String dataUri) {
    final commaIndex = dataUri.indexOf(',');
    if (commaIndex == -1) {
      return null;
    }

    final payload = dataUri.substring(commaIndex + 1);
    if (payload.isEmpty) {
      return null;
    }

    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}
