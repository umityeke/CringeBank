import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/cringe_entry.dart';
import '../screens/direct_message_thread_screen.dart';
import '../services/cringe_entry_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/entry_actions.dart';
import '../utils/safe_haptics.dart';
import '../widgets/entry_comments_sheet.dart';
import '../widgets/modern_cringe_card.dart';
import 'edit_cringe_entry_screen.dart';

class CringeEntryDetailResult {
  final String entryId;
  final CringeEntry? entry;
  final bool wasDeleted;

  const CringeEntryDetailResult._({
    required this.entryId,
    required this.entry,
    required this.wasDeleted,
  });

  factory CringeEntryDetailResult.updated(CringeEntry entry) =>
      CringeEntryDetailResult._(
        entryId: entry.id,
        entry: entry,
        wasDeleted: false,
      );

  factory CringeEntryDetailResult.deleted(String entryId) =>
      CringeEntryDetailResult._(
        entryId: entryId,
        entry: null,
        wasDeleted: true,
      );
}

class CringeEntryDetailScreen extends StatefulWidget {
  const CringeEntryDetailScreen({
    super.key,
    required this.entry,
    this.isOwnedByCurrentUser = false,
  });

  final CringeEntry entry;
  final bool isOwnedByCurrentUser;

  @override
  State<CringeEntryDetailScreen> createState() =>
      _CringeEntryDetailScreenState();
}

class _CringeEntryDetailScreenState extends State<CringeEntryDetailScreen> {
  late CringeEntry _entry;
  bool _isProcessingLike = false;
  bool _isDeleting = false;

  bool get _canManageEntry {
    if (widget.isOwnedByCurrentUser) {
      return true;
    }
    return EntryActionHelper.canManageEntry(_entry);
  }

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  Future<void> _handleLike() async {
    if (_isProcessingLike) return;
    SafeHaptics.light();
    setState(() => _isProcessingLike = true);

    try {
      // Backend'de like durumunu kontrol et
      final isLiked = await CringeEntryService.instance.isLikedByUser(
        _entry.id,
      );

      if (isLiked) {
        await CringeEntryService.instance.unlikeEntry(_entry.id);
      } else {
        await CringeEntryService.instance.likeEntry(_entry.id);
      }

      // Stream otomatik güncellenecek, UI refresh için setState yeterli
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Beğeni işlemi başarısız. Tekrar deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingLike = false);
      }
    }
  }

  void _openComments() {
    SafeHaptics.selection();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntryCommentsSheet(
        entry: _entry,
        onCommentAdded: () {
          if (!mounted) return;
          setState(() {
            _entry = _entry.copyWith(yorumSayisi: _entry.yorumSayisi + 1);
          });
        },
      ),
    );
  }

  Future<void> _handleMessage() async {
    SafeHaptics.medium();

    final targetUserId = _entry.userId.trim();
    if (targetUserId.isEmpty) {
      _showSnack('Kullanıcı bilgisi bulunamadı.');
      return;
    }

    final firebaseUser = UserService.instance.firebaseUser;
    if (firebaseUser == null) {
      _showSnack('Mesaj göndermek için giriş yapmalısınız.');
      return;
    }

    final currentUserId = firebaseUser.uid.trim();
    if (currentUserId == targetUserId) {
      _showSnack('Kendinize mesaj gönderemezsiniz.');
      return;
    }

    try {
      final targetUser = await UserService.instance.getUserById(targetUserId);
      if (targetUser == null) {
        if (mounted) _showSnack('Kullanıcı bulunamadı.');
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DirectMessageThreadScreen(
            otherUserId: targetUserId,
            initialUser: targetUser,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showSnack('Mesaj ekranı açılamadı.');
      }
    }
  }

  Future<void> _handleShare() async {
    SafeHaptics.medium();

    // Share count'u artır
    await CringeEntryService.instance.incrementShareCount(_entry.id);

    final shareText = _buildShareText(_entry);
    final headline = _entry.headline.isNotEmpty
        ? _entry.headline
        : 'Yeni Cringe Paylaşımı';
    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: headline, title: headline),
      );
    } catch (_) {
      if (mounted) {
        _showSnack('Paylaşım başlatılamadı.');
      }
    }
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.of(context).push<CringeEntry>(
      MaterialPageRoute(
        builder: (context) => EditCringeEntryScreen(entry: _entry),
      ),
    );
    if (result != null && mounted) {
      setState(() => _entry = result);
    }
  }

  Future<void> _handleDelete() async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text('Krepi Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu krepi silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final success = await CringeEntryService.instance.deleteEntry(_entry.id);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(CringeEntryDetailResult.deleted(_entry.id));
      } else {
        _showSnack('Krep silinirken bir hata oluştu.');
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Krep silinirken bir hata oluştu.');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  String _buildShareText(CringeEntry entry) {
    final buffer = StringBuffer()
      ..writeln(entry.headline)
      ..writeln()
      ..writeln(entry.aciklama)
      ..writeln()
      ..writeln('Paylaşan: ${entry.authorName}');
    return buffer.toString();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _closeWithUpdatedEntry() {
    Navigator.of(context).pop(CringeEntryDetailResult.updated(_entry));
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleEdit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Düzenle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isDeleting ? null : _handleDelete,
            icon: const Icon(Icons.delete_rounded),
            label: _isDeleting ? const Text('Siliniyor...') : const Text('Sil'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeWithUpdatedEntry();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: _closeWithUpdatedEntry,
          ),
          title: const Text('Krep', style: TextStyle(color: Colors.white)),
          centerTitle: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          children: [
            ModernCringeCard(
              entry: _entry,
              onTap: null,
              onLike: _isProcessingLike ? null : () => _handleLike(),
              onComment: _openComments,
              onMessage: () => _handleMessage(),
              onShare: _handleShare,
              onEdit: _canManageEntry ? () => _handleEdit() : null,
              onDelete: _canManageEntry ? () => _handleDelete() : null,
              isDeleteInProgress: _isDeleting,
            ),
            if (_canManageEntry) ...[
              const SizedBox(height: AppTheme.spacingL),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }
}
