import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences has not been initialized');
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences prefs;
  static const _themeKey = 'theme_mode';

  ThemeNotifier(this.prefs) : super(_loadTheme(prefs));

  static ThemeMode _loadTheme(SharedPreferences prefs) {
    final name = prefs.getString(_themeKey);
    if (name == null) return ThemeMode.system;
    return ThemeMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await prefs.setString(_themeKey, mode.name);
  }
  
  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      await setTheme(ThemeMode.dark);
    } else {
      await setTheme(ThemeMode.light);
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});
