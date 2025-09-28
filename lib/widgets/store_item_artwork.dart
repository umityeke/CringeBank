import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/store_catalog.dart';

class StoreItemArtworkCard extends StatelessWidget {
  final StoreItem item;
  final double size;
  final bool isOwned;
  final bool isEquipped;
  final bool dimmed;

  const StoreItemArtworkCard({
    super.key,
    required this.item,
    this.size = 72,
    this.isOwned = false,
    this.isEquipped = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final artwork = item.artwork;
    final colors = artwork.colors;
    final borderRadius = BorderRadius.circular(size * 0.32);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: dimmed ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: _buildShadows(colors),
        ),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: artwork.begin,
              end: artwork.end,
            ),
            borderRadius: borderRadius,
            border: Border.all(
              width: isEquipped ? 2.4 : 1.4,
              color: _borderColor(context),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: borderRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: artwork.blurSigma,
                    sigmaY: artwork.blurSigma,
                  ),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              _buildHighlightRing(),
              Icon(
                artwork.icon,
                color: Colors.white,
                size: size * 0.44,
              ),
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isEquipped ? 1 : 0,
                  child: _EquippedPill(size: size),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (!isEquipped && isOwned) ? 1 : 0,
                  child: _OwnedDot(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor(BuildContext context) {
    if (isEquipped) return Colors.white;
    if (item.highlighted) {
      return Colors.white.withValues(alpha: 0.6);
    }
    return Colors.white.withValues(alpha: 0.2);
  }

  List<BoxShadow> _buildShadows(List<Color> colors) {
    if (colors.isEmpty) return const [];
    final baseColor = colors.last;
    return [
      BoxShadow(
        color: baseColor.withValues(alpha: 0.25),
        blurRadius: size * 0.4,
        spreadRadius: size * 0.05,
        offset: Offset(0, size * 0.12),
      ),
    ];
  }

  Widget _buildHighlightRing() {
    if (!item.highlighted) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.4,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

class _EquippedPill extends StatelessWidget {
  final double size;

  const _EquippedPill({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.18,
        vertical: size * 0.08,
      ),
      decoration: BoxDecoration(
  color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white70, width: 1.2),
      ),
      child: const Text(
        'AKTİF',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _OwnedDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      width: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
