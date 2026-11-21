import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool _isRunning = false;
  double _overlayOpacity = 0.95;
  Locale _locale = const Locale('ar');
  ThemeMode _themeMode = ThemeMode.dark;

  bool get isRunning => _isRunning;
  double get overlayOpacity => _overlayOpacity;
  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  void setRunning(bool value) {
    _isRunning = value;
    notifyListeners();
  }

  void setOverlayOpacity(double value) {
    _overlayOpacity = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
