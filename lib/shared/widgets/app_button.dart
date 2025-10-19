import 'package:flutter/material.dart';

/// Primary action button that aligns with CG theme tokens.
class AppButton extends StatefulWidget {
  const AppButton.primary({
    required this.label,
    this.semanticLabel,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    super.key,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    this.semanticLabel,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    super.key,
  }) : _variant = _AppButtonVariant.secondary;

  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final _AppButtonVariant _variant;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(_cornerRadius);
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final labelStyle = _resolveLabelStyle(theme);
    final spinnerColor = labelStyle.color ?? theme.colorScheme.onPrimary;

    final buttonChild = widget.isLoading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          )
        : _buildLabel(context, labelStyle);

    Widget buildPrimary() {
      const gradient = LinearGradient(
        colors: [Color(0xFFFFB703), Color(0xFFFF2E8B), Color(0xFF3CFCD3)],
      );

      final baseShadow = widget.isLoading || isDisabled
          ? const <BoxShadow>[]
          : <BoxShadow>[
              BoxShadow(
                color: const Color(0x335B21B6).withOpacity(_hovered ? 0.5 : 1),
                blurRadius: _hovered ? 22 : 18,
                offset: const Offset(0, 8),
              ),
            ];

      final decoration = BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: baseShadow,
      );

      final content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingX,
          vertical: _paddingY,
        ),
        child: Center(child: buttonChild),
      );

      final ink = InkWell(
        borderRadius: radius,
        focusColor: Colors.white.withOpacity(0.10),
        hoverColor: Colors.white.withOpacity(0.05),
        onTap: isDisabled ? null : widget.onPressed,
        child: Ink(decoration: decoration, child: content),
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
      final surface = theme.colorScheme.surface;
      final borderColor = theme.colorScheme.outlineVariant;

      final decoration = BoxDecoration(
        color: surface.withOpacity(isDisabled ? 0.78 : 0.9),
        borderRadius: radius,
        border: Border.all(
          color: isDisabled
              ? borderColor.withOpacity(0.4)
              : borderColor.withOpacity(_hovered ? 0.9 : 0.65),
          width: 1.4,
        ),
        boxShadow: isDisabled
            ? const []
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(_hovered ? 0.28 : 0.18),
                  blurRadius: _hovered ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
      );

      final content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingX,
          vertical: _paddingY,
        ),
        child: Center(child: buttonChild),
      );

      final ink = InkWell(
        borderRadius: radius,
        focusColor: theme.colorScheme.primary.withOpacity(0.12),
        hoverColor: theme.colorScheme.primary.withOpacity(0.05),
        onTap: isDisabled ? null : widget.onPressed,
        child: Ink(decoration: decoration, child: content),
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

    final coreButton = switch (widget._variant) {
      _AppButtonVariant.primary => buildPrimary(),
      _AppButtonVariant.secondary => buildSecondary(),
    };

    final highlightDecoration = BoxDecoration(
      borderRadius: radius,
      boxShadow: [
        if (_focused && !isDisabled)
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.45),
            blurRadius: 0,
            spreadRadius: 2.4,
          ),
      ],
    );

    final semantics = Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.semanticLabel ?? widget.label,
      child: FocusableActionDetector(
        enabled: !isDisabled,
        onShowFocusHighlight: (value) {
          if (_focused != value) {
            setState(() => _focused = value);
          }
        },
        onShowHoverHighlight: (value) {
          if (_hovered != value) {
            setState(() => _hovered = value);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: highlightDecoration,
          child: coreButton,
        ),
      ),
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: semantics);
    }
    return semantics;
  }

  Widget _buildLabel(BuildContext context, TextStyle labelStyle) {
    final text = Text(
      widget.label,
      style: labelStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    final List<Widget> children = [];
    if (widget.icon != null) {
      children.add(Icon(widget.icon, size: 18, color: labelStyle.color));
      children.add(const SizedBox(width: _iconSpacing));
    }

    children.add(widget.fullWidth ? Flexible(child: text) : text);

    return Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  TextStyle _resolveLabelStyle(ThemeData theme) {
    final base =
        theme.textTheme.labelLarge ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

    return switch (widget._variant) {
      _AppButtonVariant.primary => base.copyWith(color: Colors.black),
      _AppButtonVariant.secondary => base.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    };
  }
}

enum _AppButtonVariant { primary, secondary }

const double _cornerRadius = 16;
const double _paddingX = 20;
const double _paddingY = 12;
const double _iconSpacing = 8;
