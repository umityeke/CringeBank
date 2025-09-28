import 'package:flutter/material.dart';

import '../models/cringe_entry.dart';
import '../services/competition_service.dart';
import '../services/cringe_entry_service.dart';
import '../theme/app_theme.dart';
import 'entry_comments_sheet.dart';
import 'modern_cringe_card.dart';

class CompetitionEntriesSheet extends StatefulWidget {
  const CompetitionEntriesSheet({
    super.key,
    required this.competition,
    this.onEntriesChanged,
  });

  final Competition competition;
  final ValueChanged<List<CringeEntry>>? onEntriesChanged;

  @override
  State<CompetitionEntriesSheet> createState() => _CompetitionEntriesSheetState();
}

class _CompetitionEntriesSheetState extends State<CompetitionEntriesSheet> {
  late List<CringeEntry> _entries;
  final Set<String> _locallyLikedEntryIds = <String>{};

  @override
  void initState() {
    super.initState();
    _entries = _sortEntries(widget.competition.entries);
  }

  @override
  Widget build(BuildContext context) {
    final totalComments = _entries.fold<int>(0, (sum, entry) => sum + entry.yorumSayisi);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(totalComments),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: _entries.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingL,
                        AppTheme.spacingL,
                        AppTheme.spacingL,
                        AppTheme.spacingXL,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return ModernCringeCard(
                          entry: entry,
                          onLike: () => _handleLike(entry),
                          onComment: () => _openComments(entry),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingL),
                      itemCount: _entries.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingS),
      child: Container(
        width: 46,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(int totalComments) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingL,
        AppTheme.spacingM,
        AppTheme.spacingL,
        AppTheme.spacingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.competition.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _entries.isEmpty
                ? 'Henüz paylaşılmış bir anı yok.'
                : '${_entries.length} katılımcı anısını paylaştı · Toplam $totalComments yorum',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: const Icon(Icons.forum_outlined, color: Colors.white70, size: 36),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Bu yarışmada henüz paylaşılmış bir an yok. İlk anını paylaşmak ister misin?',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLike(CringeEntry entry) async {
    if (_locallyLikedEntryIds.contains(entry.id)) {
      return;
    }

    _locallyLikedEntryIds.add(entry.id);

    try {
      final success = await CringeEntryService.instance.likeEntry(entry.id);
      if (!success) {
        _locallyLikedEntryIds.remove(entry.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beğeni kaydedilemedi. Tekrar deneyin.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _entries = _entries
            .map(
              (item) => item.id == entry.id
                  ? item.copyWith(begeniSayisi: item.begeniSayisi + 1)
                  : item,
            )
            .toList();
      });
      _notifyEntriesChanged();
    } catch (_) {
      _locallyLikedEntryIds.remove(entry.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beğeni kaydedilemedi. Tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _openComments(CringeEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntryCommentsSheet(
        entry: entry,
        onCommentAdded: () {
          if (!mounted) return;
          setState(() {
            _entries = _entries
                .map(
                  (item) => item.id == entry.id
                      ? item.copyWith(yorumSayisi: item.yorumSayisi + 1)
                      : item,
                )
                .toList();
          });
          _notifyEntriesChanged();
        },
      ),
    );
  }

  List<CringeEntry> _sortEntries(List<CringeEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  void _notifyEntriesChanged() {
    widget.onEntriesChanged?.call(List<CringeEntry>.unmodifiable(_entries));
  }
}
