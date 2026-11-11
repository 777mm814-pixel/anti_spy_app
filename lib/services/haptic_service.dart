import 'package:vibration_flutter/vibration_flutter.dart';

class HapticService {
  static Future<void> init() async {
    try { await HapticServicePlatform.instance.init(); } catch (_) {}
  }

  static Future<void> intruderAlert({required bool enabled}) async {
    if (!enabled) return;
    try {
      await HapticServicePlatform.instance.play(HapticPreset.heavyImpact);
    } catch (_) {}
  }
}
