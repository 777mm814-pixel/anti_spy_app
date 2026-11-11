import 'package:flutter/material.dart';

class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Intruder Shield',
      'camera_perm_granted': 'Camera permission granted',
      'camera_perm_required': 'Camera permission required',
      'camera_perm_denied': 'Permission permanently denied',
      'request_camera_perm': 'Request Camera Permission',
      'open_settings': 'Open App Settings',
      'overlay_perm_granted': 'Overlay permission granted',
      'overlay_perm_required': 'Overlay permission required',
      'overlay_perm_denied': 'Overlay permission permanently denied',
      'request_overlay_perm': 'Request Overlay Permission',
      'overlay_opacity': 'Overlay Opacity',
      'sensor_sensitivity': 'Sensor Sensitivity',
      'decoy_mode': 'Decoy / Camouflage Mode',
      'haptic_alert': 'Silent Haptic Alert',
      'haptic_subtitle': 'Vibration permission is granted at install',
    },
    'ar': {
      'app_title': 'درع المتطفلين',
      'camera_perm_granted': 'تم منح إذن الكاميرا',
      'camera_perm_required': 'إذن الكاميرا مطلوب',
      'camera_perm_denied': 'الإذن مرفوض نهائياً',
      'request_camera_perm': 'طلب إذن الكاميرا',
      'open_settings': 'فتح إعدادات التطبيق',
      'overlay_perm_granted': 'تم منح إذن الظهور فوق التطبيقات',
      'overlay_perm_required': 'إذن الظهور فوق التطبيقات مطلوب',
      'overlay_perm_denied': 'إذن الظهور مرفوض نهائياً',
      'request_overlay_perm': 'طلب إذن الظهور',
      'overlay_opacity': 'شفافية الطبقة',
      'sensor_sensitivity': 'حساسية الاستشعار',
      'decoy_mode': 'وضع التمويه',
      'haptic_alert': 'التنبيه الصامت',
      'haptic_subtitle': 'إذن الاهتزاز ممنوح عند التثبيت',
    }
  };

  static String get(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return _localizedValues[locale]?[key] ?? _localizedValues['en']![key] ?? key;
  }
}
