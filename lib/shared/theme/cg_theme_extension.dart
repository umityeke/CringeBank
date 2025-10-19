import 'dart:ui';

import 'package:flutter/material.dart';

class CgThemeExtension extends ThemeExtension<CgThemeExtension> {
  const CgThemeExtension({
    required this.radiusLg,
    required this.ambientShadow,
    this.surface,
    required this.glassBackground,
    required this.glassBorder,
  });

  static const CgThemeExtension dark = CgThemeExtension(
    radiusLg: 20,
    ambientShadow: [
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 26,
        spreadRadius: -4,
        offset: Offset(0, 18),
      ),
    ],
    surface: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x1A7A5CFF), Color(0x1AFF3D8A)],
    ),
    glassBackground: Color(0x1A161625),
    glassBorder: Color(0x33FFFFFF),
  );

  static const CgThemeExtension light = CgThemeExtension(
    radiusLg: 18,
    ambientShadow: [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 18,
        spreadRadius: 4,
        offset: Offset(0, 12),
      ),
    ],
    surface: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x66FFFFFF), Color(0x4DFFFFFF)],
    ),
    glassBackground: Color(0xF0FFFFFF),
    glassBorder: Color(0x66D0D4E4),
  );

  final double radiusLg;
  final List<BoxShadow> ambientShadow;
  final Gradient? surface;
  final Color glassBackground;
  final Color glassBorder;

  @override
  CgThemeExtension copyWith({
    double? radiusLg,
    List<BoxShadow>? ambientShadow,
    Gradient? surface,
    Color? glassBackground,
    Color? glassBorder,
  }) {
    return CgThemeExtension(
      radiusLg: radiusLg ?? this.radiusLg,
      ambientShadow: ambientShadow ?? this.ambientShadow,
      surface: surface ?? this.surface,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
    );
  }

  @override
  CgThemeExtension lerp(ThemeExtension<CgThemeExtension>? other, double t) {
    if (other is! CgThemeExtension) {
      return this;
    }
    return CgThemeExtension(
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t) ?? radiusLg,
      ambientShadow: _lerpShadows(ambientShadow, other.ambientShadow, t),
      surface: Gradient.lerp(surface, other.surface, t),
      glassBackground:
          Color.lerp(glassBackground, other.glassBackground, t) ?? glassBackground,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
    );
  }

  static List<BoxShadow> _lerpShadows(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) {
    final maxLength = a.length > b.length ? a.length : b.length;
    final result = <BoxShadow>[];
    for (var i = 0; i < maxLength; i++) {
      final start = i < a.length ? a[i] : const BoxShadow();
      final end = i < b.length ? b[i] : const BoxShadow();
      result.add(BoxShadow.lerp(start, end, t) ?? const BoxShadow());
    }
    return result;
  }
}
