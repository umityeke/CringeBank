import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Modern Avatar Component with status indicator
class ModernAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;
  final bool isOnline;
  final bool hasBorder;
  final VoidCallback? onTap;

  const ModernAvatar({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 40,
    this.isOnline = false,
    this.hasBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: hasBorder
              ? Border.all(color: AppTheme.dividerColor, width: 2)
              : null,
          boxShadow: AppTheme.cardShadow,
        ),
        child: Stack(
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              backgroundImage: imageUrl != null
                  ? NetworkImage(imageUrl!)
                  : null,
              child: imageUrl == null
                  ? Text(
                      initials,
                      style: TextStyle(
                        fontSize: size / 2.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : null,
            ),
            if (isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: size / 4,
                  height: size / 4,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modern Button with loading state
class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final button = isOutlined
        ? OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : (icon ?? const SizedBox.shrink()),
            label: Text(text),
            style: OutlinedButton.styleFrom(
              foregroundColor: foregroundColor,
              side: BorderSide(color: foregroundColor ?? AppTheme.primaryColor),
            ),
          )
        : ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : (icon ?? const SizedBox.shrink()),
            label: Text(text),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
            ),
          );

    return SizedBox(width: width, child: button);
  }
}

/// Modern Card with elevation and hover effects
class ModernCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool elevated;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.elevated = false,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: AppTheme.cardRadius,
              boxShadow: widget.elevated || _isHovered
                  ? AppTheme.elevatedShadow
                  : AppTheme.cardShadow,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: AppTheme.cardRadius,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => _controller.forward(),
                onTapUp: (_) => _controller.reverse(),
                onTapCancel: () => _controller.reverse(),
                onHover: (hovered) {
                  setState(() {
                    _isHovered = hovered;
                  });
                },
                borderRadius: AppTheme.cardRadius,
                child: Padding(
                  padding:
                      widget.padding ?? const EdgeInsets.all(AppTheme.spacingM),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modern Input Field with floating label
class ModernTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? errorText;
  final int? maxLines;

  const ModernTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.errorText,
    this.maxLines = 1,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: AppAnimations.fast,
          decoration: BoxDecoration(
            borderRadius: AppTheme.inputRadius,
            border: Border.all(
              color: _isFocused
                  ? AppTheme.primaryColor
                  : widget.errorText != null
                  ? AppTheme.accentColor
                  : AppTheme.dividerColor,
              width: _isFocused ? 2 : 1,
            ),
            color: AppTheme.surfaceColor,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingM,
              ),
              floatingLabelStyle: TextStyle(
                color: _isFocused
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacingXS,
              left: AppTheme.spacingS,
            ),
            child: Text(
              widget.errorText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.accentColor),
            ),
          ),
      ],
    );
  }
}

/// Modern Badge Component
class ModernBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isSmall;

  const ModernBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? AppTheme.spacingS : AppTheme.spacingS,
        vertical: isSmall ? AppTheme.spacingXS : AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
  color: backgroundColor ?? AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmall ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppTheme.primaryColor,
        ),
      ),
    );
  }
}

/// Modern Loading Indicator
class ModernLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const ModernLoading({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppTheme.primaryColor,
        ),
      ),
    );
  }
}
