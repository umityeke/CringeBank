import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core Palette
  static const Color backgroundColor = Color(0xFF100720);
  static const Color surfaceColor = Color(0xFF161228);
  static const Color cardColor = Color(0xFF1F1636);
  static const Color glassSurface = Color(0x661F1636);
  static const Color dividerColor = Color(0xFF2E2446);

  // Accent Palette
  static const Color primaryColor = Color(0xFF8A2BE2); // Neon mor
  static const Color secondaryColor = Color(0xFF2EE6D6); // Neon turkuaz
  static const Color accentPink = Color(0xFFFF4DA6);
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
  static const Color statusHealthy = Color(0xFF4ADE80);
  static const Color statusSlow = Color(0xFFF97316);
  static const Color statusError = Color(0xFFF43F5E);
  static const Color cacheBadge = Color(0xFFFDE68A);

  // Text Colors
  static const Color textPrimary = Color(0xFFF7F7FF);
  static const Color textSecondary = Color(0xFFC7C2E8);
  static const Color textMuted = Color(0xFF8E88B9);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2EE6D6), Color(0xFF8A2BE2), Color(0xFFFF4DA6)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x332EE6D6), Color(0x338A2BE2)],
  );

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
  color: const Color(0xFF0D0420).withOpacity(0.6),
      blurRadius: 18,
      spreadRadius: -8,
      offset: const Offset(0, 18),
    ),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.45),
          blurRadius: 16,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        ),
      ];

  // Border Radius
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(24));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(18));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(18));

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      error: statusError,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      brightness: Brightness.dark,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.18,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.manrope(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textMuted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: textSecondary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: textMuted,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: textMuted,
      ),
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
          borderSide: BorderSide(
            color: dividerColor.withOpacity(0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(
            color: dividerColor.withOpacity(0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: secondaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        hintStyle: GoogleFonts.inter(
          color: textMuted,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: secondaryColor,
        unselectedItemColor: textMuted,
        elevation: 12,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: dividerColor,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        actionTextColor: secondaryColor,
        contentTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: glassSurface,
  selectedColor: secondaryColor.withOpacity(0.22),
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
        colors: [Color(0xFF8A2BE2), Color(0xFF2EE6D6)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
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
