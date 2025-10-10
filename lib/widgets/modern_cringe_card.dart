import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/cringe_entry.dart';
import '../services/cringe_entry_service.dart';
import '../theme/app_theme.dart';
import 'modern_components.dart';

class ModernCringeCard extends StatefulWidget {
  final CringeEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMessage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isDeleteInProgress;

  const ModernCringeCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onMessage,
    this.onEdit,
    this.onDelete,
    this.isDeleteInProgress = false,
  });

  @override
  State<ModernCringeCard> createState() => _ModernCringeCardState();
}

class _ModernCringeCardState extends State<ModernCringeCard> {
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  @override
  void didUpdateWidget(ModernCringeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _checkIfLiked();
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final isLiked = await CringeEntryService.instance.isLikedByUser(
        widget.entry.id,
      );
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppTheme.spacingM),
                _buildContent(),
                const SizedBox(height: AppTheme.spacingM),
                _buildActions(),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
        .moveY(begin: 12, end: 0, duration: 450.ms, curve: Curves.easeOut);
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernAvatar(
          imageUrl: widget.entry.authorAvatarUrl,
          initials: _buildInitials(),
          size: 40,
          isOnline: false,
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry.isAnonim ? 'Anonim' : widget.entry.authorHandle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Row(
                children: [
                  Text(
                    _formatTimestamp(widget.entry.createdAt),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.onEdit != null || widget.onDelete != null) ...[
          const SizedBox(width: AppTheme.spacingS),
          _buildOwnerActions(),
        ],
      ],
    );
  }

  Widget _buildOwnerActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onEdit != null)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: const Icon(
              Icons.edit_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: widget.onEdit,
            tooltip: 'Krepi düzenle',
          ),
        if (widget.onEdit != null && widget.onDelete != null)
          const SizedBox(width: AppTheme.spacingS),
        if (widget.onDelete != null)
          widget.isDeleteInProgress
              ? const SizedBox(
                  height: 32,
                  width: 32,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.cringeRed,
                    size: 20,
                  ),
                  onPressed: widget.onDelete,
                  tooltip: 'Krepi sil',
                ),
      ],
    );
  }

  Widget _buildContent() {
    final category = widget.entry.kategori;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          widget.entry.headline,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          maxLines: 2,
          minFontSize: 14,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          widget.entry.aciklama,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon, size: 16, color: category.color),
            const SizedBox(width: AppTheme.spacingXS),
            Text(
              category.displayName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 0
            ? constraints.maxWidth
            : 420.0;
        final scale = (maxWidth / 440).clamp(0.7, 1.15);
        final iconSize = 20 * scale;
        final fontSize = 13 * scale.clamp(0.75, 1.15);
        final innerGap = 6 * scale.clamp(0.65, 1.15);
        final horizontalPadding = AppTheme.spacingXS * scale.clamp(0.5, 1.0);
        final verticalPadding = AppTheme.spacingXS * scale.clamp(0.7, 1.2);

        final actions = <Widget>[
          _buildMetricAction(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: _formatCount(widget.entry.likeCount),
            color: _isLiked ? AppTheme.cringeRed : AppTheme.textSecondary,
            onTap: _handleLike,
            iconSize: iconSize,
            fontSize: fontSize,
            contentGap: innerGap,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
          ),
          _buildMetricAction(
            icon: Icons.chat_bubble_outline,
            label: _formatCount(widget.entry.yorumSayisi),
            onTap: widget.onComment,
            iconSize: iconSize,
            fontSize: fontSize,
            contentGap: innerGap,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
          ),
          _buildMetricAction(
            icon: Icons.visibility_outlined,
            label: _formatCount(widget.entry.viewCount),
            color: AppTheme.textMuted,
            iconSize: iconSize,
            fontSize: fontSize,
            contentGap: innerGap,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
          ),
          _buildSecondaryAction(
            icon: Icons.send_outlined,
            label: 'Mesaj',
            onTap: widget.onMessage,
            iconSize: iconSize,
            fontSize: fontSize,
            contentGap: innerGap,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
          ),
          _buildSecondaryAction(
            icon: Icons.share_outlined,
            label: 'Paylaş',
            onTap: widget.onShare,
            iconSize: iconSize,
            fontSize: fontSize,
            contentGap: innerGap,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
          ),
        ];

        return SizedBox(
          width: maxWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: actions,
          ),
        );
      },
    );
  }

  Widget _buildMetricAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
    double iconSize = 20,
    double fontSize = 13,
    double contentGap = 6,
    double horizontalPadding = AppTheme.spacingS,
    double verticalPadding = AppTheme.spacingXS,
  }) {
    final effectiveColor = color ?? AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          children: [
            Icon(icon, size: iconSize, color: effectiveColor),
            SizedBox(width: contentGap),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontWeight: FontWeight.w500,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    double iconSize = 20,
    double fontSize = 13,
    double contentGap = 6,
    double horizontalPadding = AppTheme.spacingS,
    double verticalPadding = AppTheme.spacingXS,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          children: [
            Icon(icon, size: iconSize, color: AppTheme.textSecondary),
            SizedBox(width: contentGap),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLike() {
    // UI'da hemen güncelle (optimistic update)
    final nextValue = !_isLiked;
    setState(() {
      _isLiked = nextValue;
    });

    // Backend callback'i çağır (parent screen like işlemini yapacak)
    widget.onLike?.call();
  }

  String _buildInitials() {
    final name = widget.entry.authorName.trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      final buffer = StringBuffer();
      for (final part in parts) {
        if (part.isEmpty) continue;
        buffer.write(part[0]);
        if (buffer.length == 2) break;
      }
      if (buffer.isNotEmpty) {
        return buffer.toString().toUpperCase();
      }
    }

    final handle = widget.entry.authorHandle.replaceAll('@', '').trim();
    if (handle.length >= 2) {
      return handle.substring(0, 2).toUpperCase();
    }

    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }

    return 'CR';
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'şimdi';
    if (difference.inHours < 1) return '${difference.inMinutes}dk';
    if (difference.inDays < 1) return '${difference.inHours}sa';
    if (difference.inDays < 7) return '${difference.inDays}g';

    return '${dateTime.day}/${dateTime.month}';
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}B';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}
