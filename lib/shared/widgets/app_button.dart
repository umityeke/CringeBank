import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/cg_theme_extension.dart';

/// Primary action button that aligns with CG theme tokens.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    super.key,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    super.key,
  }) : _variant = _AppButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final _AppButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = theme.extension<CgThemeExtension>();
    final radius = BorderRadius.circular(brand?.radiusMd ?? AppSpacing.radiusMd);
    final isDisabled = onPressed == null || isLoading;

    final buttonChild = isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : _buildLabel(context);

    Widget buildPrimary() {
      final gradient = brand?.button ??
          const LinearGradient(
            colors: [Color(0xFFFFB703), Color(0xFFFF2E8B), Color(0xFF3CFCD3)],
          );
      final decoration = BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: brand?.glowShadow,
      );

      final content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Center(child: buttonChild),
      );

      final ink = InkWell(
        borderRadius: radius,
        onTap: isDisabled ? null : onPressed,
        child: Ink(
          decoration: decoration,
          child: content,
        ),
      );

      return Opacity(
        opacity: isDisabled ? 0.6 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: ink,
        ),
      );
    }

    Widget buildSecondary() {
      final decoration = BoxDecoration(
        color: brand?.glassBackground ?? theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: radius,
        border: Border.all(
          color: brand?.glassBorder ?? theme.colorScheme.outlineVariant,
        ),
        boxShadow: brand?.ambientShadow,
      );

      final content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Center(child: buttonChild),
      );

      final ink = InkWell(
        borderRadius: radius,
        onTap: isDisabled ? null : onPressed,
        child: Ink(
          decoration: decoration,
          child: content,
        ),
      );

      return Opacity(
        opacity: isDisabled ? 0.6 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: ink,
        ),
      );
    }

    final Widget button = switch (_variant) {
      _AppButtonVariant.primary => buildPrimary(),
      _AppButtonVariant.secondary => buildSecondary(),
    };

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildLabel(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      label,
      style: theme.textTheme.labelLarge,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    final List<Widget> children = [];
    if (icon != null) {
      children.add(Icon(icon, size: 18));
      children.add(const SizedBox(width: AppSpacing.xs));
    }

    children.add(fullWidth ? Flexible(child: text) : text);

    return Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}

enum _AppButtonVariant { primary, secondary }
