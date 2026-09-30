import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the application's Light / Dark / System theme mode.
///
/// The selected theme mode is saved locally using SharedPreferences,
/// so the user's choice remains after restarting the app.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  /// Default theme is Light because the Lagech design uses
  /// the Red + White light theme.
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadThemeMode();
  }

  // ============================================================
  // STORAGE KEY
  // ============================================================

  static const String _themeKey = 'app_theme_mode';

  // ============================================================
  // LOAD SAVED THEME
  // ============================================================

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? themeString = prefs.getString(_themeKey);

      if (themeString == null || themeString.isEmpty) {
        // No saved preference.
        // Keep Lagech's default Light theme.
        state = ThemeMode.light;
        return;
      }

      final ThemeMode savedMode = ThemeMode.values.firstWhere((ThemeMode mode) {
        return mode.toString() == themeString;
      }, orElse: () => ThemeMode.light);

      state = savedMode;
    } catch (_) {
      // If loading fails for any reason,
      // safely fall back to Light mode.
      state = ThemeMode.light;
    }
  }

  // ============================================================
  // CHANGE THEME
  // ============================================================

  Future<void> setThemeMode(ThemeMode mode) async {
    // Update UI immediately.
    state = mode;

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_themeKey, mode.toString());
    } catch (_) {
      // UI has already changed.
      // Ignore storage failure safely.
    }
  }

  // ============================================================
  // LIGHT THEME
  // ============================================================

  Future<void> setLightTheme() async {
    await setThemeMode(ThemeMode.light);
  }

  // ============================================================
  // DARK THEME
  // ============================================================

  Future<void> setDarkTheme() async {
    await setThemeMode(ThemeMode.dark);
  }

  // ============================================================
  // SYSTEM THEME
  // ============================================================

  Future<void> setSystemTheme() async {
    await setThemeMode(ThemeMode.system);
  }

  // ============================================================
  // TOGGLE LIGHT / DARK
  // ============================================================

  Future<void> toggleTheme() async {
    if (state == ThemeMode.dark) {
      await setLightTheme();
    } else {
      await setDarkTheme();
    }
  }

  // ============================================================
  // CHECK CURRENT THEME
  // ============================================================

  bool get isLightMode {
    return state == ThemeMode.light;
  }

  bool get isDarkMode {
    return state == ThemeMode.dark;
  }

  bool get isSystemMode {
    return state == ThemeMode.system;
  }
}
