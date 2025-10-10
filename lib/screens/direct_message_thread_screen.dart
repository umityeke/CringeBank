import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/direct_message.dart';
import '../models/user_model.dart';
import '../services/direct_message_service.dart';
import '../services/user_service.dart';
import '../utils/safe_haptics.dart';
import '../widgets/cringe_default_background.dart';
import '../theme/app_theme.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  User? _currentUser;
  User? _targetUser;
  Stream<List<DirectMessage>>? _messageStream;
  DirectMessageBlockStatus? _blockStatus;
  String? _conversationId;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isUpdatingBlock = false;
  Object? _loadError;

  String? _lastMarkedMessageId;
  final List<_PendingAttachment> _pendingAttachments = [];

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
        if (!mounted) return;
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

      final current = UserService.instance.currentUser;
      if (current == null) {
        if (!mounted) return;
        setState(() {
          _loadError = 'Profil bilgileri alınamadı.';
          _isLoading = false;
        });
        return;
      }

      User? target = widget.initialUser;
      target ??= await UserService.instance.getUserById(
        widget.otherUserId,
        forceRefresh: false,
      );

      if (!mounted) return;

      if (target == null) {
        setState(() {
          _loadError = 'Mesajlaşma hedefi bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      final blockStatusFuture = DirectMessageService.instance.getBlockStatus(
        currentUserId: current.id,
        otherUserId: target.id,
      );
      final ensureFuture = DirectMessageService.instance.ensureConversation(
        currentUser: current,
        otherUser: target,
      );
      final stream = DirectMessageService.instance.watchMessages(
        current.id,
        target.id,
      );

      final blockStatus = await blockStatusFuture;
      final ensureResult = await ensureFuture;

      if (!mounted) return;

      setState(() {
        _currentUser = current;
        _targetUser = target;
        _blockStatus = blockStatus;
        _conversationId = ensureResult.conversationId;
        _messageStream = stream;
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

  void _handleComposerTextChange() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (_hasMessageText.value != hasText) {
      _hasMessageText.value = hasText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildAppBarTitle(),
        actions: _buildAppBarActions(),
      ),
      body: CringeDefaultBackground(
        child: SafeArea(bottom: false, child: _buildBody()),
      ),
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
          backgroundColor: Colors.orange.withOpacity(0.2),
        ),
        const SizedBox(width: 12),
        Text(title),
      ],
    );
  }

  List<Widget> _buildAppBarActions() {
    final status = _blockStatus;
    final current = _currentUser;
    final target = _targetUser;
    if (status == null || current == null || target == null) {
      return const [];
    }

    final blockedByMe = status.blockedByMe;
    final blockedByOther = status.blockedByOther;

    return [
      IconButton(
        tooltip: blockedByMe ? 'Engeli kaldır' : 'Engelle',
        icon: Icon(blockedByMe ? Icons.person_remove_alt_1 : Icons.block),
        onPressed: (blockedByOther || _isUpdatingBlock)
            ? null
            : () => _toggleBlock(blockedByMe: blockedByMe),
      ),
    ];
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

    final banner = _buildConversationBanner();

    return Column(
      children: [
        if (banner != null) banner,
        Expanded(child: _buildMessageStream(stream)),
        _buildComposer(),
      ],
    );
  }

  Widget? _buildConversationBanner() {
    final status = _blockStatus;
    if (status == null) {
      return null;
    }

    if (status.blockedByOther) {
      return const _StatusBanner(
        icon: Icons.info_outline,
        message: 'Bu kullanıcı seni engellemiş. Yeni mesaj gönderemezsin.',
        color: Colors.redAccent,
      );
    }

    if (status.blockedByMe) {
      return const _StatusBanner(
        icon: Icons.block,
        message:
            'Bu kullanıcıyı engelledin. Engeli kaldırmadan mesaj gönderemezsin.',
        color: Colors.orangeAccent,
      );
    }

    return null;
  }

  Widget _buildMessageStream(Stream<List<DirectMessage>> stream) {
    return StreamBuilder<List<DirectMessage>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
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
                    'Mesajlar yüklenemedi.\n${snapshot.error}',
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

        final messages = _filterVisibleMessages(snapshot.data ?? const []);
        _handleMessagesUpdate(messages);

        if (messages.isEmpty) {
          return _buildEmptyConversation();
        }

        return _buildMessageList(messages);
      },
    );
  }

  void _handleMessagesUpdate(List<DirectMessage> messages) {
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

    _markReadPointer(messages);
  }

  void _markReadPointer(List<DirectMessage> messages) {
    final conversationId = _conversationId;
    final currentUserId = _currentUser?.id;
    if (conversationId == null || currentUserId == null) {
      return;
    }
    if (messages.isEmpty) {
      return;
    }

    final lastUnread = messages.lastWhere(
      (message) =>
          message.senderId != currentUserId &&
          !message.isDeletedFor(currentUserId) &&
          !message.isTombstoned,
      orElse: () => messages.last,
    );

    if (lastUnread.senderId == currentUserId) {
      return;
    }

    if (_lastMarkedMessageId == lastUnread.id) {
      return;
    }

    _lastMarkedMessageId = lastUnread.id;
    DirectMessageService.instance.markRead(
      conversationId: conversationId,
      messageId: lastUnread.id,
    );
  }

  List<DirectMessage> _filterVisibleMessages(List<DirectMessage> rawMessages) {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) {
      return rawMessages;
    }

    return rawMessages
        .where((message) => !message.isDeletedFor(currentUserId))
        .toList(growable: false);
  }

  Widget _buildMessageList(List<DirectMessage> messages) {
    final currentUserId = _currentUser?.id;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isOwnMessage = message.senderId == currentUserId;

        return _MessageBubble(
          message: message,
          isOwnMessage: isOwnMessage,
          onLongPress: () => _onMessageLongPress(message),
        );
      },
    );
  }

  Widget _buildEmptyConversation() {
    final target = _targetUser;
    final name = target?.displayName ?? target?.username ?? 'kullanıcı';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$name ile sohbeti başlatmak için ilk mesajı gönder.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final status = _blockStatus;
    final isBlocked = status?.isBlocked == true;
    final canSend = !isBlocked && _currentUser != null && _targetUser != null;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8, left: 16, right: 16, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingAttachments.isNotEmpty) _buildAttachmentTray(),
          Row(
            children: [
              IconButton(
                onPressed: canSend ? _pickImages : null,
                icon: const Icon(Icons.attach_file),
                color: Colors.white70,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: canSend && !_isSending,
                  style: const TextStyle(color: Colors.white),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: isBlocked
                        ? 'Engeli kaldırmadan mesaj gönderemezsin.'
                        : 'Mesaj yaz...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
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
                  final hasContent = hasText || _pendingAttachments.isNotEmpty;
                  final enabled = canSend && !_isSending && hasContent;
                  return ElevatedButton(
                    onPressed: enabled ? _handleSend : null,
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
        ],
      ),
    );
  }

  Widget _buildAttachmentTray() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        separatorBuilder: (context, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final attachment = _pendingAttachments[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  attachment.bytes,
                  height: 90,
                  width: 90,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: IconButton(
                  onPressed: () => _removeAttachment(attachment),
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.6),
                    minimumSize: const Size(28, 28),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final results = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (results.isEmpty) {
        return;
      }

      final newAttachments = <_PendingAttachment>[];
      for (final file in results) {
        final bytes = await file.readAsBytes();
        final fileName = file.name;
        final dynamic mimeValue = file.mimeType;
        String? mimeType;
        if (mimeValue is Future<String?>) {
          mimeType = await mimeValue;
        } else if (mimeValue is String) {
          mimeType = mimeValue;
        }
        final contentType = mimeType ?? _inferContentType(fileName);
        newAttachments.add(
          _PendingAttachment(
            bytes: bytes,
            fileName: fileName,
            contentType: contentType,
          ),
        );
      }

      if (newAttachments.isEmpty) {
        return;
      }

      setState(() {
        _pendingAttachments.addAll(newAttachments);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medya seçilirken hata oluştu: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _removeAttachment(_PendingAttachment attachment) {
    setState(() {
      _pendingAttachments.remove(attachment);
    });
  }

  Future<void> _handleSend() async {
    final current = _currentUser;
    final target = _targetUser;
    if (current == null || target == null) {
      return;
    }

    final text = _messageController.text.trim();
    final attachments = _pendingAttachments
        .map(
          (attachment) => DirectMessageAttachmentRequest(
            bytes: attachment.bytes,
            fileName: attachment.fileName,
            contentType: attachment.contentType,
          ),
        )
        .toList(growable: false);

    if (text.isEmpty && attachments.isEmpty) {
      return;
    }

    setState(() => _isSending = true);
    SafeHaptics.light();

    try {
      await DirectMessageService.instance.sendMessage(
        sender: current,
        recipient: target,
        text: text.isEmpty ? null : text,
        attachments: attachments,
      );

      _messageController.clear();
      _hasMessageText.value = false;

      setState(() {
        _pendingAttachments.clear();
      });

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

  Future<void> _toggleBlock({required bool blockedByMe}) async {
    final current = _currentUser;
    final target = _targetUser;
    if (current == null || target == null) {
      return;
    }

    setState(() {
      _isUpdatingBlock = true;
    });

    try {
      if (blockedByMe) {
        await DirectMessageService.instance.unblockUser(
          currentUserId: current.id,
          otherUserId: target.id,
        );
      } else {
        await DirectMessageService.instance.blockUser(
          currentUserId: current.id,
          otherUserId: target.id,
        );
      }

      final status = await DirectMessageService.instance.getBlockStatus(
        currentUserId: current.id,
        otherUserId: target.id,
      );

      if (mounted) {
        setState(() {
          _blockStatus = status;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem tamamlanamadı: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingBlock = false;
        });
      }
    }
  }

  void _onMessageLongPress(DirectMessage message) {
    final conversationId = _conversationId;
    final current = _currentUser;
    if (conversationId == null || current == null) {
      return;
    }

    final isOwn = message.senderId == current.id;
    final actions = <_MessageAction>[
      if (message.hasText && (message.text ?? '').isNotEmpty)
        _MessageAction(
          label: 'Kopyala',
          icon: Icons.copy,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: message.text ?? ''));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mesaj panoya kopyalandı')),
              );
            }
          },
        ),
      if (isOwn && message.canEdit && !message.isTombstoned)
        _MessageAction(
          label: 'Düzenle',
          icon: Icons.edit,
          onSelected: () => _editMessage(message),
        ),
      _MessageAction(
        label: 'Benden Sil',
        icon: Icons.visibility_off,
        onSelected: () => _deleteMessage(message, forEveryone: false),
      ),
      if (isOwn && !message.isTombstoned)
        _MessageAction(
          label: 'Herkesten Sil',
          icon: Icons.delete_forever,
          onSelected: () => _deleteMessage(message, forEveryone: true),
        ),
    ];

    if (actions.isEmpty) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: actions
                .map(
                  (action) => ListTile(
                    leading: Icon(action.icon),
                    title: Text(action.label),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await action.onSelected();
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _editMessage(DirectMessage message) async {
    final conversationId = _conversationId;
    if (conversationId == null) {
      return;
    }

    final controller = TextEditingController(text: message.text ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mesajı Düzenle'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Mesaj metni'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      await DirectMessageService.instance.editMessage(
        conversationId: conversationId,
        messageId: message.id,
        text: result,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesaj düzenlenemedi: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteMessage(
    DirectMessage message, {
    required bool forEveryone,
  }) async {
    final conversationId = _conversationId;
    if (conversationId == null) {
      return;
    }

    try {
      await DirectMessageService.instance.deleteMessage(
        conversationId: conversationId,
        messageId: message.id,
        forEveryone: forEveryone,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesaj silinemedi: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _inferContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    return 'application/octet-stream';
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwnMessage,
    required this.onLongPress,
  });

  final DirectMessage message;
  final bool isOwnMessage;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
  final background = isOwnMessage
    ? theme.colorScheme.primary.withOpacity(0.2)
    : Colors.white.withOpacity(0.05);
    final alignment = isOwnMessage
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: isOwnMessage
          ? const Radius.circular(20)
          : const Radius.circular(4),
      bottomRight: isOwnMessage
          ? const Radius.circular(4)
          : const Radius.circular(20),
    );

    final timestamp = DateFormat('HH:mm').format(message.createdAt);

    final children = <Widget>[];

    if (message.isTombstoned) {
      children.add(
        const Text(
          'Bu mesaj silindi.',
          style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
        ),
      );
    } else {
      for (final mediaPath in message.media) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StorageAttachmentPreview(path: mediaPath),
          ),
        );
      }

      final external = message.mediaExternal;
      if (external != null && external.url.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExternalMediaPreview(external: external),
          ),
        );
      }

      if (message.hasText) {
        children.add(
          Text(
            message.text ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        );
      }
    }

    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.editedAt != null)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text(
                  'düzenlendi',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            Text(
              timestamp,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: background, borderRadius: radius),
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _StorageAttachmentPreview extends StatefulWidget {
  const _StorageAttachmentPreview({required this.path});

  final String path;

  @override
  State<_StorageAttachmentPreview> createState() =>
      _StorageAttachmentPreviewState();
}

class _StorageAttachmentPreviewState extends State<_StorageAttachmentPreview> {
  late final Future<String> _downloadUrl;

  @override
  void initState() {
    super.initState();
    _downloadUrl = _resolveDownloadUrl(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final detectionKey = widget.path;
    final isImage = _looksLikeImage(detectionKey);

    return FutureBuilder<String>(
      future: _downloadUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: isImage ? 160 : 72,
            width: isImage ? 200 : double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.hasError) {
          return Container(
            height: 72,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Medya yüklenemedi',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final url = snapshot.data!;
        final detectionTarget = _preferExtensionSource(detectionKey, url);
        final resolvedIsImage = _looksLikeImage(detectionTarget);
        final resolvedIsVideo = _looksLikeVideo(detectionTarget);
        final resolvedIsAudio = _looksLikeAudio(detectionTarget);

        if (resolvedIsImage) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              height: 160,
              width: 200,
              fit: BoxFit.cover,
            ),
          );
        }

        final icon = resolvedIsVideo
            ? Icons.play_circle_fill
            : resolvedIsAudio
            ? Icons.audiotrack
            : Icons.insert_drive_file;

        final label = resolvedIsVideo
            ? 'Videoyu aç'
            : resolvedIsAudio
            ? 'Ses dosyasını aç'
            : 'Dosyayı aç';

        return InkWell(
          onTap: () => _launchUrl(url),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const Icon(Icons.open_in_new, color: Colors.white54, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _resolveDownloadUrl(String rawValue) async {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      throw StateError('Geçersiz medya referansı');
    }

    if (_looksLikeHttpUrl(trimmed) || trimmed.startsWith('data:')) {
      return trimmed;
    }

    if (trimmed.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(trimmed).getDownloadURL();
    }

    try {
      return await FirebaseStorage.instance.ref(trimmed).getDownloadURL();
    } on FirebaseException catch (_) {
      if (_looksLikeHttpUrl(trimmed)) {
        return trimmed;
      }
      rethrow;
    } on Exception {
      if (_looksLikeHttpUrl(trimmed)) {
        return trimmed;
      }
      rethrow;
    }
  }

  static String _preferExtensionSource(String original, String resolved) {
    final originalPath = _extractPathForExtension(original);
    if (originalPath != null && _hasKnownExtension(originalPath)) {
      return originalPath;
    }
    final resolvedPath = _extractPathForExtension(resolved);
    return resolvedPath ?? resolved;
  }

  static String? _extractPathForExtension(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.path.isNotEmpty) {
      return parsed.path;
    }
    return value;
  }

  static bool _hasKnownExtension(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac');
  }

  static bool _looksLikeImage(String path) {
    final normalized = _extractPathForExtension(path)?.toLowerCase() ?? '';
    return normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.gif') ||
        normalized.endsWith('.webp');
  }

  static bool _looksLikeVideo(String path) {
    final normalized = _extractPathForExtension(path)?.toLowerCase() ?? '';
    return normalized.endsWith('.mp4') ||
        normalized.endsWith('.mov') ||
        normalized.endsWith('.m4v') ||
        normalized.endsWith('.webm');
  }

  static bool _looksLikeAudio(String path) {
    final normalized = _extractPathForExtension(path)?.toLowerCase() ?? '';
    return normalized.endsWith('.mp3') ||
        normalized.endsWith('.m4a') ||
        normalized.endsWith('.wav') ||
        normalized.endsWith('.aac');
  }

  static bool _looksLikeHttpUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı')));
      }
    }
  }
}

class _ExternalMediaPreview extends StatelessWidget {
  const _ExternalMediaPreview({required this.external});

  final DirectMessageExternalMedia external;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(external.url);
    final label = switch (external.type.toLowerCase()) {
      'image' => 'Görsel bağlantısı',
      'video' => 'Video bağlantısı',
      'audio' => 'Ses bağlantısı',
      _ => 'Harici bağlantı',
    };

    return InkWell(
      onTap: uri == null
          ? null
          : () => launchUrl(uri, mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white70)),
            ),
            if (external.originDomain != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  external.originDomain!,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            const Icon(Icons.open_in_new, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _MessageAction {
  const _MessageAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onSelected;
}

class _PendingAttachment {
  _PendingAttachment({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
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

  static String _displayInitial(User? user) {
    final displayName = user?.displayName ?? '';
    if (displayName.isNotEmpty) {
      return displayName.characters.first.toUpperCase();
    }
    final username = user?.username ?? '';
    if (username.isNotEmpty) {
      return username.characters.first.toUpperCase();
    }
    return '👤';
  }

  static ImageProvider? _resolveImageProvider(String value) {
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
