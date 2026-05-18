import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primary = isDark ? AppColors.teal : AppColors.tealDark;
    final onBg = isDark ? AppColors.textDark : AppColors.textLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final base = TextTheme(
      displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: onBg),
      displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: onBg),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: onBg),
      titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: onBg),
      bodyLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: onBg),
      bodyMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, color: onBg),
      bodySmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400,
          color: isDark ? AppColors.textDark2 : AppColors.textLight2),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: isDark ? AppColors.bgDark : Colors.white,
        secondary: AppColors.violet,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: onBg,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: onBg, letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: onBg, size: 20),
      ),
      cardTheme: CardThemeData(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.65)
            : AppColors.surfaceLight.withValues(alpha: 0.80),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceDark2.withValues(alpha: 0.6)
            : AppColors.surfaceLight2.withValues(alpha: 0.6),
        hintStyle: GoogleFonts.inter(
          fontSize: 14, color: isDark ? AppColors.textDark3 : AppColors.textLight3,
        ),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: isDark ? AppColors.textDark2 : AppColors.textLight2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? AppColors.bgDark : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onBg,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
      useMaterial3: true,
    );
  }
}
