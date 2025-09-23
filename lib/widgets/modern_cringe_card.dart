import 'package:flutter/material.dart';
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

class _ModernCringeCardState extends State<ModernCringeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeController;
  late Animation<double> _likeAnimation;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Color _getCringeColor(double level) {
    if (level < 3) return AppTheme.secondaryColor;
    if (level < 6) return AppTheme.warningColor;
    if (level < 8) return AppTheme.cringeOrange;
    return AppTheme.cringeRed;
  }

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      onTap: widget.onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User info and cringe level
          _buildHeader(),

          const SizedBox(height: AppTheme.spacingM),

          // Content
          _buildContent(),

          const SizedBox(height: AppTheme.spacingM),

          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ModernAvatar(
          initials: widget.entry.authorName.substring(0, 2).toUpperCase(),
          size: 44,
          isOnline: true,
        ),

        const SizedBox(width: AppTheme.spacingM),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.entry.isAnonim ? 'Anonim' : widget.entry.authorName,
                    style: AppTextStyles.username,
                  ),
                  if (!widget.entry.isAnonim) ...[
                    const SizedBox(width: AppTheme.spacingXS),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ],
              ),

              Row(
                children: [
                  if (!widget.entry.isAnonim)
                    Text(
                      widget.entry.authorHandle,
                      style: AppTextStyles.handle,
                    ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    _formatTimestamp(widget.entry.createdAt),
                    style: AppTextStyles.timestamp,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Cringe Level Badge
        _buildCringeLevel(),
      ],
    );
  }

  Widget _buildCringeLevel() {
    final level = widget.entry.krepSeviyesi;
    final color = _getCringeColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            level.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          widget.entry.baslik,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),

        const SizedBox(height: AppTheme.spacingS),

        // Description
        Text(
          widget.entry.aciklama,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: AppTheme.spacingM),

        // Category
        ModernBadge(
          text: _getCategoryName(widget.entry.kategori),
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          textColor: AppTheme.primaryColor,
          isSmall: true,
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        _buildActionButton(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          count: widget.entry.begeniSayisi,
          color: _isLiked ? AppTheme.cringeRed : AppTheme.textSecondary,
          onTap: _handleLike,
        ),

        const SizedBox(width: AppTheme.spacingL),

        _buildActionButton(
          icon: Icons.chat_bubble_outline,
          count: widget.entry.yorumSayisi,
          color: AppTheme.textSecondary,
          onTap: widget.onComment,
        ),

        const Spacer(),

        _buildActionButton(
          icon: Icons.share_outlined,
          color: AppTheme.textSecondary,
          onTap: widget.onShare,
        ),

        const SizedBox(width: AppTheme.spacingS),

        _buildActionButton(
          icon: Icons.bookmark_border,
          color: AppTheme.textSecondary,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    int? count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _likeAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: icon == Icons.favorite && _isLiked
                ? _likeAnimation.value
                : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                if (count != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(count),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });

    if (_isLiked) {
      _likeController.forward().then((_) {
        _likeController.reverse();
      });
    }

    widget.onLike?.call();
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

  String _getCategoryName(CringeCategory category) {
    return category.displayName;
  }
}
