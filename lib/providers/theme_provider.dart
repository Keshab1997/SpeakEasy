import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return HiveService.isDarkMode() ? ThemeMode.dark : ThemeMode.light;
});

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

class ThemeState {
  final ThemeMode themeMode;
  final bool isDark;

  const ThemeState({
    this.themeMode = ThemeMode.light,
    this.isDark = false,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isDark,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isDark: isDark ?? this.isDark,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _loadTheme();
  }

  void _loadTheme() {
    final isDark = HiveService.isDarkMode();
    state = ThemeState(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      isDark: isDark,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final isDark = mode == ThemeMode.dark;
    await HiveService.setDarkMode(isDark);
    state = state.copyWith(themeMode: mode, isDark: isDark);
  }

  Future<void> toggleTheme() async {
    final newMode = state.isDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}
