import 'package:flutter/material.dart';

class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Intruder Shield',
      'camera_perm_granted': 'Camera permission granted',
      'camera_perm_required': 'Camera permission required',
      'camera_perm_denied': 'Permission permanently denied',
      'request_camera_perm': 'Request Camera',
      'open_settings': 'Open Settings',
      'overlay_perm_granted': 'Overlay permission granted',
      'overlay_perm_required': 'Overlay permission required',
      'overlay_perm_denied': 'Overlay permission denied',
      'request_overlay_perm': 'Request Overlay',
      'overlay_opacity': 'Overlay Opacity',
      'sensor_sensitivity': 'Sensor Sensitivity',
      'haptic_alert': 'Silent Haptic Alert',
    },
    'ar': {
      'app_title': 'درع المتطفلين',
      'camera_perm_granted': 'تم منح إذن الكاميرا',
      'camera_perm_required': 'إذن الكاميرا مطلوب',
      'camera_perm_denied': 'الإذن مرفوض نهائياً',
      'request_camera_perm': 'طلب الإذن',
      'open_settings': 'فتح الإعدادات',
      'overlay_perm_granted': 'تم منح إذن الظهور',
      'overlay_perm_required': 'إذن الظهور مطلوب',
      'overlay_perm_denied': 'إذن الظهور مرفوض',
      'request_overlay_perm': 'طلب الظهور',
      'overlay_opacity': 'شفافية الطبقة',
      'sensor_sensitivity': 'حساسية الاستشعار',
      'haptic_alert': 'التنبيه الصامت',
    }
  };

  static String get(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return _localizedValues[locale]?[key] ?? _localizedValues['en']![key] ?? key;
  }
}
