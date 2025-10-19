import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/theme/cg_theme_extension.dart';

class AppTheme {
  // Core Palette
  static const Color backgroundColor = Color(0xFF0B0B10);
  static const Color surfaceColor = Color(0xFF12131D);
  static const Color cardColor = Color(0xFF151521);
  static const Color glassSurface = Color(0x33151521);
  static const Color dividerColor = Color(0xFF26263A);

  static const Color lightBackgroundColor = Color(0xFFF7F8FC);
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color lightCardColor = Color(0xFFF1F3FF);
  static const Color lightGlassSurface = Color(0xCCFFFFFF);
  static const Color lightDividerColor = Color(0xFFD9DEEA);

  // Accent Palette
  static const Color primaryColor = Color(0xFFFF3D8A);
  static const Color secondaryColor = Color(0xFF7A5CFF);
  static const Color accentPink = Color(0xFFFF3D8A);
  static const Color accentBlue = Color(0xFF5C5CFF);

  // Legacy aliases for backwards compatibility
  static Color get accentColor => secondaryColor;
  static Color get warningColor => statusSlow;
  static Color get textTertiary => textMuted;
  static LinearGradient get primaryGradient => heroGradient;
  static List<BoxShadow> get elevatedShadow => cardShadow;
  static const Color cringeOrange = Color(0xFFFF8E53);
  static const Color cringeRed = Color(0xFFFF4D79);

  // Status Chips
  static const Color statusHealthy = Color(0xFF22C55E);
  static const Color statusSlow = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);
  static const Color cacheBadge = Color(0xFFFDE68A);

  // Text Colors
  static const Color textPrimary = Color(0xFFF5F6F8);
  static const Color textSecondary = Color(0xFFC4C6D0);
  static const Color textMuted = Color(0xFFA7A9B0);
  static const Color lightTextPrimary = Color(0xFF171A21);
  static const Color lightTextSecondary = Color(0xFF4F5567);
  static const Color lightTextMuted = Color(0xFF768094);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7A5CFF), Color(0xFFFF3D8A)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1A7A5CFF), Color(0x1AFF3D8A)],
  );

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF05050A).withOpacity(0.7),
      blurRadius: 28,
      spreadRadius: -12,
      offset: const Offset(0, 22),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.38),
      blurRadius: 20,
      spreadRadius: 3,
      offset: const Offset(0, 8),
    ),
  ];

  // Border Radius
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(24));
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(16),
  );
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(12));

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  static ThemeData get lightTheme => _buildLightTheme();

  static ThemeData get darkTheme => _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: lightSurfaceColor,
      background: lightBackgroundColor,
      error: statusError,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightTextPrimary,
      onBackground: lightTextPrimary,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackgroundColor,
      brightness: Brightness.light,
      extensions: const <ThemeExtension<dynamic>>[CgThemeExtension.light],
    );

    final textTheme = _brandTextTheme(
      base.textTheme,
      primary: lightTextPrimary,
      secondary: lightTextSecondary,
      muted: lightTextMuted,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCardColor,
        shadowColor: Colors.black.withOpacity(0.06),
        shape: const RoundedRectangleBorder(borderRadius: cardRadius),
        surfaceTintColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: const StadiumBorder(),
          elevation: 1,
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingS,
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightGlassSurface,
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: lightDividerColor.withOpacity(0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: lightDividerColor.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: secondaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        hintStyle: GoogleFonts.inter(color: lightTextMuted, fontSize: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightTextMuted,
        elevation: 12,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: lightDividerColor,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightCardColor,
        actionTextColor: primaryColor,
        contentTextStyle: GoogleFonts.inter(
          color: lightTextPrimary,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightGlassSurface,
        selectedColor: primaryColor.withOpacity(0.18),
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: lightTextSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      background: backgroundColor,
      error: statusError,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      onBackground: textPrimary,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      brightness: Brightness.dark,
      extensions: const <ThemeExtension<dynamic>>[CgThemeExtension.dark],
    );

    final textTheme = _brandTextTheme(
      base.textTheme,
      primary: textPrimary,
      secondary: textSecondary,
      muted: textMuted,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        shadowColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: cardRadius),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: secondaryColor,
          side: const BorderSide(color: secondaryColor, width: 1.4),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingS,
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassSurface,
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: dividerColor.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: dividerColor.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: secondaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMuted,
        elevation: 12,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: dividerColor,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        actionTextColor: primaryColor,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glassSurface,
        selectedColor: primaryColor.withOpacity(0.24),
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: textSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
      ),
    );
  }

  static LinearGradient get linearGradientPrimary => const LinearGradient(
    colors: [Color(0xFF7A5CFF), Color(0xFFFF3D8A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static TextTheme _brandTextTheme(
    TextTheme base, {
    required Color primary,
    required Color secondary,
    required Color muted,
  }) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.18,
        color: primary,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: primary,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: primary,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: primary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: secondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: muted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: secondary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: muted,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: muted,
      ),
    );
  }
}

// Custom Text Styles
class AppTextStyles {
  static TextStyle username = GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
  );

  static TextStyle handle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppTheme.textSecondary,
  );

  static TextStyle timestamp = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppTheme.textMuted,
  );

  static TextStyle cringeLevel = GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppTheme.accentPink,
    letterSpacing: 0.6,
  );
}

// Animation Durations
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);
}
