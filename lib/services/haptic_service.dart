import 'package:flutter/services.dart';

class HapticService {
  static Future<void> init() async {
    // لا حاجة لتهيئة مسبقة مع HapticFeedback
  }

  static Future<void> intruderAlert({required bool enabled}) async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // تجاهل الأخطاء إن لم يدعم الجهاز الاهتزاز
    }
  }
}
