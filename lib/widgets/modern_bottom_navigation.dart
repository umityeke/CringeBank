import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ModernBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Ana Sayfa',
              ),
              _buildNavItem(
                context,
                index: 1,
                icon: Icons.search_outlined,
                activeIcon: Icons.search,
                label: 'Arama',
              ),
              _buildAddButton(context),
              _buildNavItem(
                context,
                index: 3,
                icon: Icons.favorite_outline,
                activeIcon: Icons.favorite,
                label: 'Aktivite',
              ),
              _buildNavItem(
                context,
                index: 4,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: AppAnimations.fast,
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 26,
                  color: isActive
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: AppAnimations.fast,
                width: isActive ? 6 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onTap(2),
          borderRadius: BorderRadius.circular(12),
          child: const Icon(Icons.add, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
