import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _themeColorKey = 'theme_color';

  ThemeMode _themeMode = ThemeMode.light; // Changed from system to light
  String _themeColor = 'blue';

  ThemeMode get themeMode => _themeMode;
  String get themeColor => _themeColor;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? 0; // Changed from 2 to 0 (light)
    _themeMode = ThemeMode.values[themeModeIndex];
    _themeColor = prefs.getString(_themeColorKey) ?? 'blue';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, mode.index);
      notifyListeners();
    }
  }

  Future<void> setThemeColor(String color) async {
    if (_themeColor != color) {
      _themeColor = color;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeColorKey, color);
      notifyListeners();
    }
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      final window = WidgetsBinding.instance.window;
      return window.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
}