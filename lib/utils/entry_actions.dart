import 'package:flutter/material.dart';

import '../models/cringe_entry.dart';
import '../screens/edit_cringe_entry_screen.dart';
import '../services/cringe_entry_service.dart';
import '../services/user_service.dart';
import 'safe_haptics.dart';

class EntryActionHelper {
  const EntryActionHelper._();

  static bool canManageEntry(CringeEntry entry) {
    final currentUserId = UserService.instance.firebaseUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      return false;
    }
    return entry.userId == currentUserId;
  }

  static Future<bool> editEntry(BuildContext context, CringeEntry entry) async {
    SafeHaptics.selection();

    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditCringeEntryScreen(entry: entry),
      ),
    );

    if (!context.mounted) {
      return didUpdate == true;
    }

    if (didUpdate == true) {
      _showSnack(context, 'Krep güncellendi.', backgroundColor: Colors.green);
      return true;
    }

    return false;
  }

  static Future<bool> confirmAndDeleteEntry(
    BuildContext context,
    CringeEntry entry,
  ) async {
    if (!canManageEntry(entry)) {
      _showSnack(
        context,
        'Bu krepi yönetmek için yetkin yok.',
        backgroundColor: Colors.redAccent,
      );
      return false;
    }

    SafeHaptics.medium();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text('Krepi Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu krepi silmek istediğine emin misin? Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (!context.mounted) {
      return false;
    }

    if (confirmed != true) {
      return false;
    }

    try {
      final success = await CringeEntryService.instance.deleteEntry(entry.id);
      if (!context.mounted) {
        return success;
      }

      if (success) {
        SafeHaptics.selection();
        _showSnack(context, 'Krep silindi.', backgroundColor: Colors.redAccent);
        return true;
      } else {
        _showSnack(
          context,
          'Krep silinirken bir sorun oluştu.',
          backgroundColor: Colors.redAccent,
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return false;
      }
      _showSnack(
        context,
        'Krep silinemedi: $error',
        backgroundColor: Colors.redAccent,
      );
    }

    return false;
  }

  static void _showSnack(
    BuildContext context,
    String message, {
    Color backgroundColor = Colors.orange,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
