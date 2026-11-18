import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool _powerOn = false;
  double _overlayOpacity = 0.85;
  double _sensitivity = 0.5;
  bool _hapticEnabled = true;
  bool _autoOverlay = true; // إضافة: مفتاح التعتيم التلقائي
  ThemeMode _themeMode = ThemeMode.dark;

  bool get powerOn => _powerOn;
  double get overlayOpacity => _overlayOpacity;
  double get sensitivity => _sensitivity;
  bool get hapticEnabled => _hapticEnabled;
  bool get autoOverlay => _autoOverlay;
  ThemeMode get themeMode => _themeMode;

  void setPower(bool v) { _powerOn = v; notifyListeners(); }
  void setOpacity(double v) { _overlayOpacity = v.clamp(0.2, 1.0); notifyListeners(); }
  void setSensitivity(double v) { _sensitivity = v.clamp(0.1, 1.0); notifyListeners(); }
  void setHaptic(bool v) { _hapticEnabled = v; notifyListeners(); }
  void setAutoOverlay(bool v) { _autoOverlay = v; notifyListeners(); }
  void setTheme(ThemeMode m) { _themeMode = m; notifyListeners(); }
}
