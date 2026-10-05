import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF14141E);
  static const Color surfaceElevated = Color(0xFF1E1E2C);
  static const Color cardBorder = Color(0xFF28283C);
  
  static const Color primary = Color(0xFFE50914); // Netflix / FlixDirect Red
  static const Color primaryHover = Color(0xFFFF222E);
  static const Color accentGold = Color(0xFFFFC107); // IMDb rating
  static const Color accentGreen = Color(0xFF10B981); // Direct R2 High-Speed
  static const Color accentBlue = Color(0xFF3B82F6); // Gofile / Mirror
  static const Color accentPurple = Color(0xFF8B5CF6); // VikingFile

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0B0);
  static const Color textMuted = Color(0xFF6B6B80);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentGold,
        surface: surface,
        error: Color(0xFFEF4444),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        titleMedium: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 14,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: textSecondary,
          fontSize: 13,
        ),
        bodySmall: GoogleFonts.outfit(
          color: textMuted,
          fontSize: 11,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }
}
