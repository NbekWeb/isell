import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'theme_mode';

  // Get theme mode from storage
  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey);
    
    if (themeString == null) {
      // Default to system theme if not set
      return ThemeMode.system;
    }
    
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  // Save theme mode to storage
  static Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    String themeString;
    
    switch (themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }
    
    await prefs.setString(_themeKey, themeString);
  }

  // Toggle between dark and light
  static Future<ThemeMode> toggleTheme(ThemeMode currentTheme) async {
    ThemeMode newTheme;
    
    if (currentTheme == ThemeMode.dark) {
      newTheme = ThemeMode.light;
    } else {
      newTheme = ThemeMode.dark;
    }
    
    await setThemeMode(newTheme);
    return newTheme;
  }
}

