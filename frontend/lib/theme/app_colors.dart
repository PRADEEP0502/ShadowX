import 'package:flutter/material.dart';

class AppColors {
  static const Color amoledBlack = Color(0xFF050505);
  static const Color darkSurface = Color(0xFF0A0A0A);
  static const Color cardDark = Color(0xFF121212);
  static const Color cardDarker = Color(0xFF0F0F0F);

  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color primaryBlue = Color(0xFF3B82F6);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7B2FF7), Color(0xFF3A8DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color onlineGreen = Color(0xFF2EE59D);
  static const Color offlineGray = Color(0xFF6B7280);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textTertiary = Colors.white54;
  static const Color textHint = Colors.white38;

  static const Color divider = Color(0xFF2A2A2A);
  static const Color glassBorder = Color(0xFF3A3A3A);

  static Color glassBackground = Colors.white.withOpacity(0.05);
  static Color glassBlur = Colors.black.withOpacity(0.3);

  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFFFA500);
}