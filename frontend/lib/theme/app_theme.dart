import 'package:flutter/material.dart';

class AppColors {
  // Theme base colors
  static const Color primary = Color(0xFF009E83);       // Teal for dashboard / primary brand
  static const Color primaryDark = Color(0xFF006B58);   // Darker teal
  static const Color primaryLight = Color(0xFFEFFCF9);  // Very light teal background/badge
  static const Color primaryBorder = Color(0xFFCCF5EC); // Light border teal

  // Cyan Accent colors (used in Login)
  static const Color accent = Color(0xFF0891B2);        // Cyan accent
  static const Color accentDark = Color(0xFF0E7490);    // Dark cyan
  static const Color accentLight = Color(0xFFE0F2FE);   // Light cyan background
  static const Color accentBorder = Color(0xFFE2E8F0);  // Border color cyan/slate
  static const Color accentFocus = Color(0xFF0891B2);   // Active input border

  // General backgrounds
  static const Color bgPage = Color(0xFFF0F4F3);        // Light grey-teal background
  static const Color bgLogin = Color(0xFFF4F7FA);       // Login page background
  static const Color bgCard = Color(0xFFFFFFFF);        // White card background
  static const Color bgInput = Color(0xFFF8FAFB);       // Light inputs

  // Status & Warning colors
  static const Color success = Color(0xFF009E83);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color error = Color(0xFFE63946);

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A);   // Dark slate
  static const Color textSecondary = Color(0xFF4A7A72); // Muted teal-slate
  static const Color textSecondaryLogin = Color(0xFF64748B); // Secondary slate
  static const Color textMuted = Color(0xFFCBD5E1);      // Light grey text
  static const Color textDark = Color(0xFF0D1F1B);       // Near black text
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.error,
        background: AppColors.bgPage,
      ),
      scaffoldBackgroundColor: AppColors.bgPage,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textSecondary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
