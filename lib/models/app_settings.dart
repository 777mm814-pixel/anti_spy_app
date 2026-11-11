import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  bool _powerOn = false;
  double _overlayOpacity = 0.85;
  double _sensitivity = 0.5;
  bool _decoyEnabled = false;
  bool _hapticEnabled = true;
  ThemeMode _themeMode = ThemeMode.dark;

  bool get powerOn => _powerOn;
  double get overlayOpacity => _overlayOpacity;
  double get sensitivity => _sensitivity;
  bool get decoyEnabled => _decoyEnabled;
  bool get hapticEnabled => _hapticEnabled;
  ThemeMode get themeMode => _themeMode;

  void setPower(bool v) { _powerOn = v; notifyListeners(); }
  void setOpacity(double v) { _overlayOpacity = v.clamp(0.2, 1.0); notifyListeners(); }
  void setSensitivity(double v) { _sensitivity = v.clamp(0.1, 1.0); notifyListeners(); }
  void setDecoy(bool v) { _decoyEnabled = v; notifyListeners(); }
  void setHaptic(bool v) { _hapticEnabled = v; notifyListeners(); }
  void setTheme(ThemeMode m) { _themeMode = m; notifyListeners(); }
}
