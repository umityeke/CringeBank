import 'package:flutter/material.dart';

import 'cg_theme_extension.dart';

class CgTheme {
  const CgTheme._();

  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        const CgThemeExtension(
          radiusLg: 20,
          ambientShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 28,
              spreadRadius: 4,
              offset: Offset(0, 12),
            ),
          ],
          surface: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xCCFFFFFF),
              Color(0xB3F2F5FF),
            ],
          ),
          glassBackground: Color(0x14FFFFFF),
          glassBorder: Color(0x33FFFFFF),
        ),
      ],
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF05031A),
      useMaterial3: true,
    );
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        const CgThemeExtension(
          radiusLg: 20,
          ambientShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 32,
              spreadRadius: 2,
              offset: Offset(0, 16),
            ),
          ],
          surface: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xCC111827),
              Color(0xB3081120),
            ],
          ),
          glassBackground: Color(0x1A1F2937),
          glassBorder: Color(0x33FFFFFF),
        ),
      ],
    );
  }
}
