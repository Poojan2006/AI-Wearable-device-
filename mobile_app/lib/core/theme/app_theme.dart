import 'package:flutter/material.dart';

class AppTheme {
  // Curated Luxury Tech Palette: Deep Indigo-Slate & Radiant Accents
  static const Color primaryDark = Color(0xFF090D1A); // Luxurious Deep Space Navy
  static const Color surfaceDark = Color(0xFF101728); // Refined Slate Surface
  static const Color cardDark = Color(0xFF151E33); // Elevated Card Surface
  static const Color elevatedDark = Color(0xFF1D2942); // Interactive / Elevated
  static const Color borderSubtle = Color(0xFF243350); // Clean Slate Border
  static const Color borderLight = Color(0x2238BDF8); // Soft Cyan Rim

  // Harmonious Status & Indicator Accents
  static const Color accentIndigo = Color(0xFF6366F1); // Radiant Indigo (Brand Primary)
  static const Color accentCyan = Color(0xFF38BDF8); // Electric Sky / Telemetry
  static const Color accentMint = Color(0xFF10B981); // Emerald Teal (Safety / Optimal)
  static const Color accentAmber = Color(0xFFF59E0B); // Radiant Amber (Warning)
  static const Color accentCoral = Color(0xFFF43F5E); // Vivid Crimson Pulse (Emergency)

  // Compatibility aliases
  static const Color accentOrange = Color(0xFF6366F1);
  static const Color safeGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFF43F5E);
  static const Color emergencyPurple = Color(0xFFE11D48);

  // Modern Typography Colors
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentIndigo,
        secondary: accentCyan,
        surface: surfaceDark,
        error: accentCoral,
        onPrimary: Colors.white,
        onSurface: textLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: textLight,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentIndigo,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: accentIndigo.withAlpha(80),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentIndigo, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      ),
    );
  }

  static ThemeData get lightTheme {
    return darkTheme;
  }
}
