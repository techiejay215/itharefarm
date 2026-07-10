// lib/config/colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF2E7D32);      // Deep Green
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF1B5E20);

  // Secondary
  static const Color white = Color(0xFFFFFFFF);
  static const Color amber = Color(0xFFF9A825);        // Accent for alerts

  // Backgrounds
  static const Color background = Color(0xFFF5F5F5);   // Light Gray
  static const Color cardBg = Color(0xFFFFFFFF);

  // Text
  static const Color textDark = Color(0xFF424242);
  static const Color textLight = Color(0xFF757575);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Shadow
  static const Color shadow = Color(0x0D000000);

  // Status badges
  static const Color lactatingBg = Color(0xFFE8F5E9);
  static const Color lactatingText = Color(0xFF2E7D32);
  static const Color pregnantBg = Color(0xFFFFF8E1);
  static const Color pregnantText = Color(0xFFF9A825);
  static const Color dryBg = Color(0xFFF5F5F5);
  static const Color dryText = Color(0xFF757575);
  static const Color calfBg = Color(0xFFE3F2FD);
  static const Color calfText = Color(0xFF1976D2);
  static const Color soldBg = Color(0xFFFFEBEE);
  static const Color soldText = Color(0xFFD32F2F);

  // Borders
  static const Color border = Color(0xFFE0E0E0);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppBorderRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
}

class AppFontSizes {
  static const double small = 12.0;
  static const double body = 14.0;
  static const double medium = 16.0;
  static const double large = 20.0;
  static const double xlarge = 24.0;
  static const double huge = 32.0;
}