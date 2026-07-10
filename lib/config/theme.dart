// lib/config/theme.dart

import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.amber,
      surface: AppColors.cardBg,
      error: Color(0xFFD32F2F),
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(
        color: AppColors.primary,
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      hintStyle: const TextStyle(
        color: AppColors.textLight,
        fontSize: 14,
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    cardTheme: const CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: AppColors.textDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: AppColors.textDark,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: AppColors.textLight,
      ),
    ),
    
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 16,
    ),
  );
}
