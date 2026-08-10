import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF16A34A);
  static const Color primaryDark = Color(0xFF128A3E);
  static const Color primaryDeep = Color(0xFF0F6E30);
  static const Color primaryLight = Color(0xFFDCFCE7);
  static const Color primaryMid = Color(0xFFBBF3D4);
  static const Color primaryGlow = Color(0x2616A34A);

  static const Color bg = Color(0xFFF7F8F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color placeholder = Color(0xFFC4C9D0);

  static const Color text = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDim = Color(0xFF9CA3AF);

  static const Color red = Color(0xFFDC2626);
  static const Color redDark = Color(0xFFB91C1C);
  static const Color redLight = Color(0xFFFEE2E2);
  static const Color redBorder = Color(0xFFFECACA);
  static const Color redBg = Color(0xFFFEF2F2);

  static const Color yellow = Color(0xFFF59E0B);
  static const Color yellowLight = Color(0xFFFEF3C7);
  static const Color yellowText = Color(0xFFB45309);

  static const Color blue = Color(0xFF3B82F6);
  static const Color dark = Color(0xFF1A1A1A);
  static const Color grayLight = Color(0xFFF3F4F6);
  static const Color grayMid = Color(0xFFD1D5DB);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.bg,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

TextStyle poppins(double size, FontWeight weight, Color color) {
  return GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);
}

TextStyle inter(double size, FontWeight weight, Color color) {
  return GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);
}
