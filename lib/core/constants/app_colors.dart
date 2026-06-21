import 'package:flutter/material.dart';

class AppColors {
  // Light Theme Colors
  static const Color primary = Color(0xFF2563EB); // Modern Royal Blue
  static const Color secondary = Color(0xFF10B981); // Emerald Green
  static const Color accent = Color(0xFFF59E0B); // Amber Yellow
  
  static const Color backgroundLight = Color(0xFFF8FAFC); // Very light grey/blue
  static const Color surfaceLight = Colors.white;
  static const Color onBackgroundLight = Color(0xFF0F172A); // Slate 900
  static const Color onSurfaceLight = Color(0xFF1E293B); // Slate 800
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color onBackgroundDark = Color(0xFFF8FAFC); // Slate 50
  static const Color onSurfaceDark = Color(0xFFE2E8F0); // Slate 200
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color borderDark = Color(0xFF334155); // Slate 700

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color error = Color(0xFFEF4444); // Red
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color info = Color(0xFF06B6D4); // Cyan

  // Card Gradients
  static const List<Color> primaryGradient = [Color(0xFF2563EB), Color(0xFF3B82F6)];
  static const List<Color> secondaryGradient = [Color(0xFF10B981), Color(0xFF059669)];
  static const List<Color> accentGradient = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const List<Color> purpleGradient = [Color(0xFF8B5CF6), Color(0xFF7C3AED)];
  static const List<Color> pinkGradient = [Color(0xFFEC4899), Color(0xFFDB2777)];
  static const List<Color> infoGradient = [Color(0xFF06B6D4), Color(0xFF0891B2)];
}
