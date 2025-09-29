import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../modern_components.dart';

class UserSearchTile extends StatelessWidget {
  final User user;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final Widget? trailing;

  const UserSearchTile({
    super.key,
    required this.user,
    this.onTap,
    this.onFollow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = user.isPremium;
    final isVerified = user.isVerified;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          color: Colors.white.withOpacity(0.04),
        ),
        child: Row(
          children: [
            ModernAvatar(
        imageUrl: user.avatarUrl,
        initials: _buildInitials(),
              size: 48,
              isOnline: user.isActive,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                        ),
                      ),
                      if (isVerified)
                        Padding(
                          padding: const EdgeInsets.only(left: AppTheme.spacingXS),
                          child: Icon(
                            Icons.verified,
                            color: AppTheme.accentBlue,
                            size: 18,
                          ),
                        ),
                      if (isPremium)
                        Padding(
                          padding: const EdgeInsets.only(left: AppTheme.spacingXS),
                          child: Icon(
                            Icons.star_rounded,
                            color: AppTheme.accentPink,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    '@${user.username}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                  ),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      user.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.6),
                            height: 1.3,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingS),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildStatChip(
                        icon: Icons.group_outlined,
                        label: '${_formatCount(user.followersCount)} takipçi',
                      ),
                      _buildStatChip(
                        icon: Icons.post_add,
                        label: '${_formatCount(user.entriesCount)} krep',
                      ),
                      _buildStatChip(
                        icon: Icons.bolt,
                        label: 'Seviye ${user.krepLevel}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            trailing ?? _buildFollowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    return InkWell(
      onTap: onFollow,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A18), Color(0xFFAF002D)],
          ),
        ),
        child: const Text(
          'Profili Gör',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _buildInitials() {
    final name = user.displayName.trim();
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

    final username = user.username.trim();
    if (username.length >= 2) {
      return username.substring(0, 2).toUpperCase();
    }

    return 'CB';
  }

  String _formatCount(int value) {
    if (value < 1000) return value.toString();
    if (value < 1000000) return '${(value / 1000).toStringAsFixed(1)}B';
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
}
