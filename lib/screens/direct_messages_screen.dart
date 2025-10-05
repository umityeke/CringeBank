import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/direct_message.dart';
import '../models/user_model.dart';
import '../services/direct_message_service.dart';
import '../services/user_service.dart';
import '../utils/safe_haptics.dart';
import 'direct_message_thread_screen.dart';
import 'modern_login_screen.dart';

class DirectMessagesScreen extends StatefulWidget {
  const DirectMessagesScreen({super.key});

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen> {
  User? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _hydrateCurrentUser();
  }

  Future<void> _hydrateCurrentUser() async {
    final cachedUser = UserService.instance.currentUser;

    if (mounted) {
      setState(() {
        _currentUser = cachedUser;
        _isLoadingUser = cachedUser == null;
      });
    }

    if (cachedUser != null) {
      return;
    }

    final firebaseUser = UserService.instance.firebaseUser;
    if (firebaseUser != null) {
      await UserService.instance.loadUserData(firebaseUser.uid);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser = UserService.instance.currentUser;
      _isLoadingUser = false;
    });
  }

  Future<void> _refresh() async {
    await _hydrateCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Mesajlar'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _currentUser;
    if (user == null) {
      return _buildAuthPrompt();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: StreamBuilder<List<DirectMessageThread>>(
        stream: DirectMessageService.instance.watchThreads(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final threads = snapshot.data ?? const <DirectMessageThread>[];
          if (threads.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final tileData = _resolveThreadTileData(thread, user.id);

              return _DirectMessageThreadTile(
                data: tileData,
                onTap: () => _openThread(thread, currentUser: user),
              );
            },
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemCount: threads.length,
          );
        },
      ),
    );
  }

  void _openThread(DirectMessageThread thread, {required User currentUser}) {
    final targetUserId = thread.otherParticipantId(currentUser.id);
    if (targetUserId == null || targetUserId.isEmpty) {
      return;
    }

    SafeHaptics.selection();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            DirectMessageThreadScreen(otherUserId: targetUserId),
      ),
    );
  }

  _ThreadTileData _resolveThreadTileData(
    DirectMessageThread thread,
    String userId,
  ) {
    final otherUserId = thread.otherParticipantId(userId);
    final meta = otherUserId != null
        ? thread.participantMeta[otherUserId] ??
              const DirectMessageParticipantMeta(
                displayName: 'Bilinmeyen',
                username: 'anonymous',
                avatar: '👤',
              )
        : const DirectMessageParticipantMeta(
            displayName: 'Bilinmeyen',
            username: 'anonymous',
            avatar: '👤',
          );

    final trimmedMessage = thread.lastMessage.trim();
    final lastMessagePreview = trimmedMessage.isEmpty
        ? 'Yeni konuyu başlat'
        : thread.lastSenderId == userId
        ? 'Sen: $trimmedMessage'
        : trimmedMessage;

    return _ThreadTileData(
      displayName: meta.displayName.isNotEmpty
          ? meta.displayName
          : meta.username,
      username: meta.username,
      avatar: meta.avatar,
      lastMessage: lastMessagePreview,
      timestampLabel: _formatTimestamp(thread.lastMessageAt),
      unreadCount: thread.unreadCount,
    );
  }

  Widget _buildAuthPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'Mesajları görmek için giriş yapmalısın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ModernLoginScreen()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Giriş Yap',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Mesajlar yüklenirken bir hata oldu.\n${error ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: _hydrateCurrentUser,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.forum_outlined, size: 48, color: Colors.white70),
              SizedBox(height: 16),
              Text(
                'Henüz mesajın yok. Bir konuşma başlat!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} dk';
    }
    if (isSameDay(now, timestamp)) {
      return DateFormat('HH:mm').format(timestamp);
    }
    if (now.year == timestamp.year) {
      return DateFormat('dd MMM').format(timestamp);
    }
    return DateFormat('dd.MM.yyyy').format(timestamp);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ThreadTileData {
  const _ThreadTileData({
    required this.displayName,
    required this.username,
    required this.avatar,
    required this.lastMessage,
    required this.timestampLabel,
    required this.unreadCount,
  });

  final String displayName;
  final String username;
  final String avatar;
  final String lastMessage;
  final String timestampLabel;
  final int unreadCount;
}

class _DirectMessageThreadTile extends StatelessWidget {
  const _DirectMessageThreadTile({required this.data, required this.onTap});

  final _ThreadTileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _ThreadAvatar(
                avatar: data.avatar,
                displayName: data.displayName,
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.15,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (data.timestampLabel.isNotEmpty)
                          Text(
                            data.timestampLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@${data.username}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.unreadCount > 0) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    data.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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

  static String _avatarInitial(String avatar, String displayName) {
    final trimmed = avatar.trim();
    if (trimmed.isNotEmpty && trimmed.length <= 3) {
      return trimmed;
    }

    if (displayName.isNotEmpty) {
      return displayName.characters.first.toUpperCase();
    }

    return '👤';
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({
    required this.avatar,
    required this.displayName,
    required this.radius,
    required this.backgroundColor,
  });

  final String avatar;
  final String displayName;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final trimmed = avatar.trim();
    final fallback = _DirectMessageThreadTile._avatarInitial(
      trimmed,
      displayName,
    );
    final imageProvider = _resolveImageProvider(trimmed);

    if (imageProvider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: backgroundColor,
      );
    }

    if (trimmed.isNotEmpty && trimmed.length <= 3) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Text(trimmed, style: const TextStyle(fontSize: 22)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(fallback, style: const TextStyle(fontSize: 22)),
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
