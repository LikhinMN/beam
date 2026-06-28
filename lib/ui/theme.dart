import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized color palette for the Beam app.
class BeamColors {
  static const Color background = Color(0xFF09090B);
  static const Color surface = Color(0xFF18181B);
  static const Color surfaceHighlight = Color(0xFF27272A);
  static const Color accent = Color(0xFF38BDF8); // Vibrant cyan-blue
  static const Color accentSecondary = Color(0xFF818CF8); // Indigo
  static const Color success = Color(0xFF34D399);
  static const Color error = Color(0xFFF87171);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accent, accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Centralized typography styles for the Beam app.
class BeamTextStyles {
  static final TextStyle headline = GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: BeamColors.textPrimary,
    letterSpacing: -0.5,
  );

  static final TextStyle title = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: BeamColors.textPrimary,
  );

  static final TextStyle body = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: BeamColors.textPrimary,
  );

  static final TextStyle caption = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: BeamColors.textSecondary,
  );

  static final TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: BeamColors.accent,
    letterSpacing: 8.0,
  );
}

/// The global app theme.
final ThemeData beamTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: BeamColors.background,
  colorScheme: const ColorScheme.dark(
    primary: BeamColors.accent,
    surface: BeamColors.surface,
    error: BeamColors.error,
    onPrimary: BeamColors.textPrimary,
    onSurface: BeamColors.textPrimary,
  ),
  cardTheme: CardThemeData(
    color: BeamColors.surface,
    elevation: 8,
    shadowColor: Colors.black.withOpacity(0.4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: BeamColors.surfaceHighlight, width: 1),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: BeamColors.accent,
      foregroundColor: BeamColors.background,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: BeamTextStyles.body.copyWith(fontWeight: FontWeight.bold),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: BeamColors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: BeamColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: BeamColors.accent,
    foregroundColor: BeamColors.background,
    elevation: 4,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: BeamColors.surfaceHighlight.withOpacity(0.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: BeamColors.accent, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  ),
);
