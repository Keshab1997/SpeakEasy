import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'NotoSansBengali',
  fontFamilyFallback: const ['NotoSansBengali'],
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surfaceDark,
    error: Colors.redAccent,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.onSurfaceDark,
  ),
  scaffoldBackgroundColor: AppColors.backgroundDark,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundDark,
    foregroundColor: AppColors.onBackgroundDark,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackgroundDark,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surfaceDark,
    elevation: 2,
    shadowColor: Colors.black.withOpacity(0.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.borderDark, width: 0.5),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.surfaceDark,
    indicatorColor: AppColors.primary.withOpacity(0.2),
    labelTextStyle: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        );
      }
      return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondaryDark,
      );
    }),
    iconTheme: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const IconThemeData(
          color: Colors.white,
          size: 26,
        );
      }
      return const IconThemeData(
        color: AppColors.textSecondaryDark,
        size: 24,
      );
    }),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackgroundDark,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.onBackgroundDark,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.onBackgroundDark,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: AppColors.onBackgroundDark,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: AppColors.textSecondaryDark,
    ),
  ).apply(fontFamily: 'NotoSansBengali'),
);
