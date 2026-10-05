import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic Classic Diplomatic Design Palette for SpecPass.
/// Features a luxury consular aesthetic without harsh pitch-black
/// or stark black-and-white contrast:
/// - Diplomatic Executive: Rich Royal Midnight Navy & Antique Gold
/// - Consular Prestige: Warm Alabaster Ivory, Diplomatic Azure & Gold Seal
class AppPalette {
  final bool isDark;
  final Color surfaceDim;
  final Color surface;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;

  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color tertiary;
  final Color tertiaryContainer;

  final Color goldAccent;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;

  const AppPalette({
    required this.isDark,
    required this.surfaceDim,
    required this.surface,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.goldAccent,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
  });
}

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Diplomatic Executive Palette (Warm Royal Navy - Zero Pitch Black)
  // ---------------------------------------------------------------------------
  static const Color surfaceDim = Color(0xFF0C192E); // Deep Diplomatic Navy
  static const Color surface = Color(0xFF11213D); // Royal Embassy Navy
  static const Color surfaceBright = Color(0xFF243B66);
  static const Color surfaceContainerLowest = Color(0xFF091325);
  static const Color surfaceContainerLow = Color(0xFF152747);
  static const Color surfaceContainer = Color(0xFF1A3057);
  static const Color surfaceContainerHigh = Color(0xFF223C6B);
  static const Color surfaceContainerHighest = Color(0xFF2C4A82);

  static const Color onSurface = Color(0xFFEDF2F9); // Soft Alabaster White
  static const Color onSurfaceVariant = Color(0xFF98ACC8); // Warm Slate Blue
  static const Color outline = Color(0xFF385382);
  static const Color outlineVariant = Color(0xFF1D345C);

  static const Color primary = Color(0xFF2563EB); // Royal Sapphire
  static const Color primaryContainer = Color(0xFF173875);
  static const Color secondary = Color(0xFF38BDF8); // Sky Azure
  static const Color secondaryContainer = Color(0xFF0369A1);
  static const Color tertiary = Color(0xFF10B981); // Biometric Mint
  static const Color tertiaryContainer = Color(0xFF064E3B);
  
  static const Color goldAccent = Color(0xFFD4AF37); // Diplomatic Crest Gold
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFF78350F);
  static const Color error = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFF7F1D1D);

  // ---------------------------------------------------------------------------
  // Consular Prestige Classic Palette (Warm Ivory & Royal Navy - Zero Pitch Black)
  // ---------------------------------------------------------------------------
  static const Color lightSurfaceDim = Color(0xFFEEF2F7);
  static const Color lightSurface = Color(0xFFF7F9FC); // Warm Consular Canvas
  static const Color lightSurfaceBright = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF1F4F9);
  static const Color lightSurfaceContainer = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHigh = Color(0xFFE2E8F0);
  static const Color lightSurfaceContainerHighest = Color(0xFFCBD5E1);

  static const Color lightOnSurface = Color(0xFF0C1A3C); // Diplomatic Deep Navy
  static const Color lightOnSurfaceVariant = Color(0xFF475569); // Slate Grey
  static const Color lightOutline = Color(0xFF94A3B8);
  static const Color lightOutlineVariant = Color(0xFFE2E8F0);

  static const Color lightPrimary = Color(0xFF005BB2); // Consular Sapphire Blue
  static const Color lightPrimaryContainer = Color(0xFFDBEAFE);
  static const Color lightSecondary = Color(0xFF0284C7); // Diplomatic Sky Azure
  static const Color lightSecondaryContainer = Color(0xFFE0F2FE);
  static const Color lightTertiary = Color(0xFF059669); // Biometric Emerald Mint
  static const Color lightTertiaryContainer = Color(0xFFD1FAE5);
  static const Color lightGoldAccent = Color(0xFFC5A059); // Antique Gold Seal

  // Palette Instances
  static const AppPalette darkPalette = AppPalette(
    isDark: true,
    surfaceDim: surfaceDim,
    surface: surface,
    surfaceBright: surfaceBright,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    primary: primary,
    primaryContainer: primaryContainer,
    secondary: secondary,
    secondaryContainer: secondaryContainer,
    tertiary: tertiary,
    tertiaryContainer: tertiaryContainer,
    goldAccent: goldAccent,
    warning: warning,
    warningContainer: warningContainer,
    error: error,
    errorContainer: errorContainer,
  );

  static const AppPalette lightPalette = AppPalette(
    isDark: false,
    surfaceDim: lightSurfaceDim,
    surface: lightSurface,
    surfaceBright: lightSurfaceBright,
    surfaceContainerLowest: lightSurfaceContainerLowest,
    surfaceContainerLow: lightSurfaceContainerLow,
    surfaceContainer: lightSurfaceContainer,
    surfaceContainerHigh: lightSurfaceContainerHigh,
    surfaceContainerHighest: lightSurfaceContainerHighest,
    onSurface: lightOnSurface,
    onSurfaceVariant: lightOnSurfaceVariant,
    outline: lightOutline,
    outlineVariant: lightOutlineVariant,
    primary: lightPrimary,
    primaryContainer: lightPrimaryContainer,
    secondary: lightSecondary,
    secondaryContainer: lightSecondaryContainer,
    tertiary: lightTertiary,
    tertiaryContainer: lightTertiaryContainer,
    goldAccent: lightGoldAccent,
    warning: warning,
    warningContainer: warningContainer,
    error: error,
    errorContainer: errorContainer,
  );

  /// Helper to get the active palette from BuildContext
  static AppPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkPalette : lightPalette;
  }

  static AppPalette colors(BuildContext context) => of(context);

  // ---------------------------------------------------------------------------
  // Dark Theme: Diplomatic Executive Navy
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        onSurface: onSurface,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        error: error,
        outline: outline,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.03 * 32,
          color: onSurface,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02 * 24,
          color: onSurface,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01 * 20,
          color: onSurface,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01 * 18,
          color: onSurface,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
        ),
        bodySmall: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.04 * 12,
          color: onSurfaceVariant,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08 * 10,
          color: onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: outlineVariant, width: 1),
        ),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDim.withValues(alpha: 0.90),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Light Theme: Consular Prestige Classic
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightSurface,
      colorScheme: const ColorScheme.light(
        surface: lightSurface,
        onSurface: lightOnSurface,
        primary: lightPrimary,
        primaryContainer: lightPrimaryContainer,
        secondary: lightSecondary,
        secondaryContainer: lightSecondaryContainer,
        tertiary: lightTertiary,
        tertiaryContainer: lightTertiaryContainer,
        error: error,
        outline: lightOutline,
        outlineVariant: lightOutlineVariant,
        surfaceContainerLowest: lightSurfaceContainerLowest,
        surfaceContainerLow: lightSurfaceContainerLow,
        surfaceContainer: lightSurfaceContainer,
        surfaceContainerHigh: lightSurfaceContainerHigh,
        surfaceContainerHighest: lightSurfaceContainerHighest,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.03 * 32,
          color: lightOnSurface,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02 * 24,
          color: lightOnSurface,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01 * 20,
          color: lightOnSurface,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01 * 18,
          color: lightOnSurface,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: lightOnSurface,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: lightOnSurfaceVariant,
        ),
        bodySmall: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: lightOnSurfaceVariant,
        ),
        labelLarge: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: lightOnSurface,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.04 * 12,
          color: lightOnSurfaceVariant,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08 * 10,
          color: lightOnSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightOutlineVariant, width: 1),
        ),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface.withValues(alpha: 0.92),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: lightOnSurface),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightOnSurface,
        ),
      ),
    );
  }
}
