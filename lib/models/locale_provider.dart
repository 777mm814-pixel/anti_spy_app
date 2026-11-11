import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar'); // اللغة الافتراضية عربي

  Locale get locale => _locale;

  void toggleLocale() {
    _locale = _locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    notifyListeners();
  }
}
