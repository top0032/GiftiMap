import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary 세련된 민트/네이비 계열
  static const Color primaryTeal = Color(0xFF0D9488); // Tailwind Teal 600
  static const Color secondaryNavy = Color(0xFF0F172A); // Tailwind Slate 900
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.notoSansKrTextTheme();

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        secondary: secondaryNavy,
        background: backgroundLight,
        surface: surfaceWhite,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: secondaryNavy),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: secondaryNavy,
          fontWeight: FontWeight.w700,
        ),
      ),
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 4,
        shadowColor: secondaryNavy.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceWhite,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      )
    );
  }
}
