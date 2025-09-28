import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/cringe_entry.dart';
import '../theme/app_theme.dart';
import 'modern_components.dart';

class ModernCringeCard extends StatefulWidget {
  final CringeEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  const ModernCringeCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
  });

  @override
  State<ModernCringeCard> createState() => _ModernCringeCardState();
}

class _ModernCringeCardState extends State<ModernCringeCard> {
  bool _isLiked = false;

  Color _getCringeColor(double level) {
    if (level < 3) return AppTheme.secondaryColor;
    if (level < 6) return AppTheme.warningColor;
    if (level < 8) return AppTheme.cringeOrange;
    return AppTheme.cringeRed;
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
    ).animate()
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
                widget.entry.isAnonim ? 'Anonim' : widget.entry.authorName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Row(
                children: [
                  if (!widget.entry.isAnonim) ...[
                    Flexible(
                      child: Text(
                        widget.entry.authorHandle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                  ],
                  Text(
                    _formatTimestamp(widget.entry.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        _buildCringeBadge(),
      ],
    );
  }

  Widget _buildCringeBadge() {
    final level = widget.entry.krepSeviyesi;
    final color = _getCringeColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
  color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
  border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${level.toStringAsFixed(1)}/10',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final category = widget.entry.kategori;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          widget.entry.baslik,
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        _buildMetricAction(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(widget.entry.begeniSayisi),
          color: _isLiked ? AppTheme.cringeRed : AppTheme.textSecondary,
          onTap: _handleLike,
        ),
        const SizedBox(width: AppTheme.spacingL),
        _buildMetricAction(
          icon: Icons.chat_bubble_outline,
          label: _formatCount(widget.entry.yorumSayisi),
          onTap: widget.onComment,
        ),
        const Spacer(),
        _buildSecondaryAction(
          icon: Icons.share_outlined,
          label: 'Paylaş',
          onTap: widget.onShare,
        ),
      ],
    );
  }

  Widget _buildMetricAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: AppTheme.spacingXS,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: AppTheme.spacingXS,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLike() {
    final nextValue = !_isLiked;
    setState(() {
      _isLiked = nextValue;
    });

    if (nextValue) {
      widget.onLike?.call();
    }
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
