import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'NotoSansBengali',
  fontFamilyFallback: const ['NotoSansBengali'],
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surfaceLight,
    error: Colors.redAccent,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.onSurfaceLight,
  ),
  scaffoldBackgroundColor: AppColors.backgroundLight,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    foregroundColor: AppColors.onBackgroundLight,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackgroundLight,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surfaceLight,
    elevation: 2,
    shadowColor: Colors.black.withOpacity(0.05),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.surfaceLight,
    indicatorColor: AppColors.primary.withOpacity(0.1),
    labelTextStyle: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        );
      }
      return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondaryLight,
      );
    }),
    iconTheme: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const IconThemeData(
          color: AppColors.primary,
          size: 26,
        );
      }
      return const IconThemeData(
        color: AppColors.textSecondaryLight,
        size: 24,
      );
    }),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackgroundLight,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackgroundLight,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.onBackgroundLight,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: AppColors.onBackgroundLight,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: AppColors.textSecondaryLight,
    ),
  ).apply(fontFamily: 'NotoSansBengali'),
);
