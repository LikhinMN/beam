import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized color palette for the Beam app.
class BeamColors {
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color accent = Color(0xFF00C2FF); // Electric Blue
  static const Color success = Color(0xFF00E096);
  static const Color error = Color(0xFFFF4C4C);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8A8A);
}

/// Centralized typography styles for the Beam app.
class BeamTextStyles {
  static final TextStyle headline = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
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
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: BeamColors.accent,
      foregroundColor: BeamColors.textPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: BeamTextStyles.body.copyWith(fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: BeamColors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: BeamColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: BeamColors.accent,
    foregroundColor: BeamColors.textPrimary,
    elevation: 0,
  ),
);
