import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/cg_theme_extension.dart';

/// CG temasındaki cam efekti yüzeyleri standart hale getiren panel.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.gradient,
    this.backgroundColor,
    this.borderColor,
    this.blurSigma = 18,
    this.borderWidth = 1,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? borderColor;
  final double blurSigma;
  final double borderWidth;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final extension = Theme.of(context).extension<CgThemeExtension>();
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(extension?.radiusLg ?? 18);

    final boxShadow = extension?.ambientShadow ?? const <BoxShadow>[];
    final gradientOrColor = gradient ?? extension?.surface;
    final effectiveBackgroundColor = gradientOrColor == null
    ? backgroundColor ??
      extension?.glassBackground ??
      Colors.white.withValues(alpha: 0.04)
        : null;
    final effectiveBorderColor =
        borderColor ?? extension?.glassBorder ?? Colors.white24;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradientOrColor,
              color: effectiveBackgroundColor,
              border: Border.all(
                width: borderWidth,
                color: effectiveBorderColor,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
