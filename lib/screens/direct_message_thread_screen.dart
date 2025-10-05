import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/direct_message.dart';
import '../models/user_model.dart';
import '../services/direct_message_service.dart';
import '../services/user_service.dart';
import '../utils/safe_haptics.dart';

class DirectMessageThreadScreen extends StatefulWidget {
  const DirectMessageThreadScreen({
    super.key,
    required this.otherUserId,
    this.initialUser,
  });

  final String otherUserId;
  final User? initialUser;

  @override
  State<DirectMessageThreadScreen> createState() =>
      _DirectMessageThreadScreenState();
}

class _DirectMessageThreadScreenState extends State<DirectMessageThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _hasMessageText = ValueNotifier<bool>(false);

  User? _currentUser;
  User? _targetUser;
  bool _isLoading = true;
  bool _isSending = false;
  Stream<List<DirectMessage>>? _messageStream;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _hasMessageText.value = _messageController.text.trim().isNotEmpty;
    _messageController.addListener(_handleComposerTextChange);
    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerTextChange);
    _messageController.dispose();
    _scrollController.dispose();
    _hasMessageText.dispose();
    super.dispose();
  }

  Future<void> _initializeConversation() async {
    try {
      final firebaseUser = UserService.instance.firebaseUser;
      if (firebaseUser == null) {
        setState(() {
          _loadError = 'Mesaj göndermek için giriş yapmalısın.';
          _isLoading = false;
        });
        return;
      }

      if (UserService.instance.currentUser == null) {
        await UserService.instance.loadUserData(firebaseUser.uid);
        if (!mounted) return;
      }

      final User? maybeCurrent = UserService.instance.currentUser;
      if (maybeCurrent == null) {
        if (!mounted) return;
        setState(() {
          _loadError = 'Profil bilgileri alınamadı.';
          _isLoading = false;
        });
        return;
      }

      final User current = maybeCurrent;

      User? target = widget.initialUser;
      target ??= await UserService.instance.getUserById(
        widget.otherUserId,
        forceRefresh: false,
      );

      if (!mounted) return;

      if (target == null) {
        if (!mounted) return;
        setState(() {
          _loadError = 'Mesajlaşma hedefi bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      final User resolvedTarget = target;

      if (!mounted) return;

      setState(() {
        _currentUser = current;
        _targetUser = resolvedTarget;
        _messageStream = DirectMessageService.instance.watchMessages(
          current.id,
          resolvedTarget.id,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: _buildAppBarTitle()),
      body: _buildBody(),
    );
  }

  Widget _buildAppBarTitle() {
    final target = _targetUser;
    final title = target?.displayName.isNotEmpty == true
        ? target!.displayName
        : target?.username ?? 'Bilinmeyen';

    return Row(
      children: [
        _AppBarAvatar(
          user: target,
          backgroundColor: Colors.orange.withValues(alpha: 0.2),
        ),
        const SizedBox(width: 12),
        Text(title),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                _loadError.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _initializeConversation,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    final stream = _messageStream;
    if (stream == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<DirectMessage>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data ?? const <DirectMessage>[];

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              });

              if (messages.isEmpty) {
                return _buildEmptyConversation();
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isOwnMessage = message.senderId == _currentUser?.id;
                  return _MessageBubble(
                    message: message,
                    isOwnMessage: isOwnMessage,
                  );
                },
              );
            },
          ),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildEmptyConversation() {
    final target = _targetUser;
    final name = target?.displayName ?? target?.username ?? 'kullanıcı';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$name ile sohbeti başlatmak için ilk mesajı gönder. ',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final canSend = _currentUser != null && _targetUser != null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: canSend && !_isSending,
                style: const TextStyle(color: Colors.white),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                onChanged: (_) => _handleComposerTextChange(),
                decoration: InputDecoration(
                  hintText: 'Mesaj yaz... ',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<bool>(
              valueListenable: _hasMessageText,
              builder: (context, hasText, _) {
                final isEnabled = canSend && hasText && !_isSending;
                return ElevatedButton(
                  onPressed: isEnabled ? _handleSend : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null || _targetUser == null) {
      return;
    }

    setState(() => _isSending = true);
    SafeHaptics.light();

    try {
      await DirectMessageService.instance.sendMessage(
        sender: _currentUser!,
        recipient: _targetUser!,
        text: text,
      );
      _messageController.clear();
      _hasMessageText.value = false;
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (error, stack) {
      if (kDebugMode) {
        print('Mesaj gönderilemedi: $error\n$stack');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesaj gönderilemedi: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _handleComposerTextChange() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (_hasMessageText.value != hasText) {
      _hasMessageText.value = hasText;
    }
  }
}

class _AppBarAvatar extends StatelessWidget {
  const _AppBarAvatar({required this.user, required this.backgroundColor});

  final User? user;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatar.trim() ?? '';
    final fallback = _displayInitial(user);
    final provider = _resolveImageProvider(avatar);

    if (provider != null) {
      return CircleAvatar(
        backgroundImage: provider,
        backgroundColor: backgroundColor,
      );
    }

    if (avatar.isNotEmpty && avatar.length <= 3) {
      return CircleAvatar(
        backgroundColor: backgroundColor,
        child: Text(avatar, style: const TextStyle(color: Colors.white)),
      );
    }

    return CircleAvatar(
      backgroundColor: backgroundColor,
      child: Text(fallback, style: const TextStyle(color: Colors.white)),
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

String _displayInitial(User? target) {
  if (target == null) return '👤';

  final avatar = target.avatar.trim();
  if (avatar.isNotEmpty && avatar.length <= 3) {
    return avatar;
  }

  final titleSource = target.displayName.isNotEmpty
      ? target.displayName
      : target.username.isNotEmpty
      ? target.username
      : target.email;

  if (titleSource.isEmpty) {
    return '👤';
  }

  return titleSource.characters.first.toUpperCase();
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isOwnMessage});

  final DirectMessage message;
  final bool isOwnMessage;

  @override
  Widget build(BuildContext context) {
    final alignment = isOwnMessage
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = isOwnMessage
        ? Colors.orange.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.08);
    final textColor = isOwnMessage ? Colors.black : Colors.white;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: Radius.circular(isOwnMessage ? 4 : 18),
            bottomLeft: Radius.circular(isOwnMessage ? 18 : 4),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
        ),
      ),
    );
  }
}
