import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/user_model.dart';
import '../../../../services/style_search_service.dart';

@immutable
class MediaTag {
  const MediaTag({
    required this.userId,
    required this.username,
    required this.position,
    this.displayName,
  });

  final String userId;
  final String username;
  final Offset position;
  final String? displayName;

  MediaTag copyWith({
    String? userId,
    String? username,
    Offset? position,
    String? displayName,
  }) {
    return MediaTag(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      position: position ?? this.position,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MediaTag &&
        other.userId == userId &&
        other.username == username &&
        other.position == position &&
        other.displayName == displayName;
  }

  @override
  int get hashCode => Object.hash(userId, username, position, displayName);
}

class MediaTaggingCanvas extends StatefulWidget {
  const MediaTaggingCanvas({
    Key? key,
    required this.tags,
    required this.onChanged,
    required this.background,
    this.mentionSuggestionFetcher,
    this.lookupDebounce = const Duration(milliseconds: 280),
    this.minQueryLength = 2,
    this.blockedUserIds = const <String>{},
    this.blockedUsernames = const <String>{},
    this.onBlockedUserAttempt,
  }) : super(key: key ?? const Key('mediaTaggingCanvas'));

  final List<MediaTag> tags;
  final ValueChanged<List<MediaTag>> onChanged;
  final Widget background;
  final MentionSuggestionFetcher? mentionSuggestionFetcher;
  final Duration lookupDebounce;
  final int minQueryLength;
  final Set<String> blockedUserIds;
  final Set<String> blockedUsernames;
  final ValueChanged<String>? onBlockedUserAttempt;

  @override
  State<MediaTaggingCanvas> createState() => _MediaTaggingCanvasState();
}

class _MediaTaggingCanvasState extends State<MediaTaggingCanvas> {
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    _showHint = widget.tags.isEmpty;
  }

  @override
  void didUpdateWidget(covariant MediaTaggingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tags.isNotEmpty && _showHint) {
      setState(() {
        _showHint = false;
      });
    }
    if (widget.tags.isEmpty && oldWidget.tags.isNotEmpty) {
      setState(() {
        _showHint = true;
      });
    }
  }

  Future<void> _handleTap(Offset localPosition, Size size) async {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final picked = await _pickUser();
    if (!mounted || picked == null) {
      return;
    }

    if (_isBlocked(picked.user)) {
      widget.onBlockedUserAttempt?.call(picked.user.username);
      return;
    }

    final normalized = Offset(
      (localPosition.dx / size.width).clamp(0.0, 1.0),
      (localPosition.dy / size.height).clamp(0.0, 1.0),
    );

    final next = List<MediaTag>.from(widget.tags);
    final newTag = MediaTag(
      userId: picked.user.id,
      username: picked.user.username,
      displayName: picked.user.displayName,
      position: normalized,
    );

    final existingIndex = next.indexWhere(
      (tag) => tag.userId == picked.user.id,
    );
    if (existingIndex >= 0) {
      next[existingIndex] = newTag;
    } else {
      next.add(newTag);
    }

    widget.onChanged(next);

    if (_showHint) {
      setState(() {
        _showHint = false;
      });
    }
  }

  bool _isBlocked(User user) {
    if (user.id.isNotEmpty && widget.blockedUserIds.contains(user.id)) {
      return true;
    }
    final normalizedUsername = user.username.trim().toLowerCase();
    if (normalizedUsername.isEmpty) {
      return false;
    }
    return widget.blockedUsernames.contains(normalizedUsername);
  }

  void _removeTag(MediaTag tag) {
    final next = List<MediaTag>.from(widget.tags)
      ..removeWhere((candidate) => candidate.userId == tag.userId);
    widget.onChanged(next);
    if (next.isEmpty) {
      setState(() {
        _showHint = true;
      });
    }
  }

  Future<_PickedUser?> _pickUser() {
  final fetcher =
    widget.mentionSuggestionFetcher ?? const _DefaultMentionFetcher().call;
    return showModalBottomSheet<_PickedUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return _TagSuggestionSheet(
          mentionSuggestionFetcher: fetcher,
          debounceDuration: widget.lookupDebounce,
          minQueryLength: widget.minQueryLength,
          blockedUserIds: widget.blockedUserIds,
          blockedUsernames: widget.blockedUsernames,
          onBlockedUserAttempt: widget.onBlockedUserAttempt,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTapUp: (details) => _handleTap(details.localPosition, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: widget.background),
              ...widget.tags.map(_buildTag),
              if (_showHint) const _TapHintOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(MediaTag tag) {
    return Align(
      alignment: Alignment(
        (tag.position.dx * 2) - 1,
        (tag.position.dy * 2) - 1,
      ),
      child: _TagChip(tag: tag, onDeleted: () => _removeTag(tag)),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.onDeleted});

  final MediaTag tag;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final display = tag.displayName?.trim().isNotEmpty == true
        ? tag.displayName!
        : '@${tag.username}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_pin_circle,
              size: 16,
              color: Colors.orangeAccent,
            ),
            const SizedBox(width: 6),
            Text(
              display,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDeleted,
              child: const Icon(Icons.close, size: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _TapHintOverlay extends StatelessWidget {
  const _TapHintOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.2),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 18, left: 16, right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.touch_app, color: Colors.white70, size: 28),
          SizedBox(height: 6),
          Text(
            'Medya üzerinde etiketlemek istediğin yere dokun',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagSuggestionSheet extends StatefulWidget {
  const _TagSuggestionSheet({
    required this.mentionSuggestionFetcher,
    required this.debounceDuration,
    required this.minQueryLength,
    required this.blockedUserIds,
    required this.blockedUsernames,
    this.onBlockedUserAttempt,
  });

  final MentionSuggestionFetcher mentionSuggestionFetcher;
  final Duration debounceDuration;
  final int minQueryLength;
  final Set<String> blockedUserIds;
  final Set<String> blockedUsernames;
  final ValueChanged<String>? onBlockedUserAttempt;

  @override
  State<_TagSuggestionSheet> createState() => _TagSuggestionSheetState();
}

class _TagSuggestionSheetState extends State<_TagSuggestionSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;
  List<User> _results = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < widget.minQueryLength) {
      setState(() {
        _results = const [];
        _errorMessage = null;
        _infoMessage = null;
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(widget.debounceDuration, () => _runLookup(query));
  }

  Future<void> _runLookup(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final fetched = await widget.mentionSuggestionFetcher(query, limit: 8);
      if (!mounted) {
        return;
      }
      final allowed = <User>[];
      final blocked = <User>[];
      for (final user in fetched) {
        if (_isBlocked(user)) {
          blocked.add(user);
        } else {
          allowed.add(user);
        }
      }
      final infoMessage = blocked.isNotEmpty
          ? _formatBlockedInfo(blocked)
          : null;
      final errorMessage = allowed.isEmpty && blocked.isNotEmpty
          ? 'Engellenmiş kullanıcıları etiketleyemezsin.'
          : null;
      setState(() {
        _results = allowed;
        _isLoading = false;
        _infoMessage = infoMessage;
        _errorMessage = errorMessage;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Öneriler alınırken bir sorun oluştu. Tekrar dene.';
        _infoMessage = null;
      });
    }
  }

  void _select(User user) {
    if (_isBlocked(user)) {
      widget.onBlockedUserAttempt?.call(user.username);
      setState(() {
        _errorMessage = 'Bu kullanıcıyı etiketleyemezsin.';
        _infoMessage = _formatBlockedInfo([user]);
      });
      return;
    }
    Navigator.of(context).pop(_PickedUser(user));
  }

  bool _isBlocked(User user) {
    if (user.id.isNotEmpty && widget.blockedUserIds.contains(user.id)) {
      return true;
    }
    final normalizedUsername = user.username.trim().toLowerCase();
    if (normalizedUsername.isEmpty) {
      return false;
    }
    return widget.blockedUsernames.contains(normalizedUsername);
  }

  String _formatBlockedInfo(List<User> users) {
    final handles = users
        .map((user) => user.username.trim())
        .where((username) => username.isNotEmpty)
        .map((username) => '@$username')
        .toList();
    if (handles.isEmpty) {
      return 'Bu kullanıcıyı etiketleyemezsin.';
    }
    const maxHandles = 3;
    final visible = handles.take(maxHandles).toList();
    final remaining = handles.length - visible.length;
    if (remaining > 0) {
      return '${visible.join(', ')} ve +$remaining kişi etiketlenemez (engel nedeniyle).';
    }
    return '${visible.join(', ')} etiketlenemez (engel nedeniyle).';
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Kimi etiketlemek istiyorsun?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('mediaTagSearchField'),
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '@kullanıcı ara',
                  prefixText: '@',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else ...[
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_infoMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _infoMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (_results.isEmpty && _errorMessage == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      widget.minQueryLength <= 1
                          ? 'En az birkaç karakter yazmaya başla. Trend kullanıcılar burada görünecek.'
                          : 'Öneri almak için en az ${widget.minQueryLength} karakter yaz.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (_results.isNotEmpty)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final displayName = user.displayName.trim().isNotEmpty
                              ? user.displayName
                              : user.username;
                          final source = displayName.trim().isNotEmpty
                              ? displayName.trim()
                              : user.username.trim();
                          final avatarInitial = source.isNotEmpty
                              ? source[0].toUpperCase()
                              : '?';
                          return ListTile(
                            key: Key('mediaTagSuggestion_${user.id}'),
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              child: Text(
                                avatarInitial,
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ),
                            title: Text(displayName),
                            subtitle: Text('@${user.username}'),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () => _select(user),
                          );
                        },
            separatorBuilder: (context, index) =>
              const Divider(height: 1),
                        itemCount: _results.length,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedUser {
  _PickedUser(this.user);

  final User user;
}

class _DefaultMentionFetcher {
  const _DefaultMentionFetcher();

  Future<List<User>> call(String query, {int limit = 6}) {
    return StyleSearchService.fetchMentionSuggestions(query, limit: limit);
  }
}
