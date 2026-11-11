import 'package:flutter_screen_overlay/flutter_screen_overlay.dart';

class OverlayService {
  static Future<void> showPrivacyOverlay({required double opacity, String? decoyImagePath}) async {
    final has = await FlutterScreenOverlay.isPermissionGranted();
    if (!has) await FlutterScreenOverlay.requestPermission();

    await FlutterScreenOverlay.showOverlay(
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'Intruder Shield',
      overlayContent: 'Privacy protection active',
      enableDrag: false,
    );

    await FlutterScreenOverlay.shareData({
      'type': 'privacy',
      'opacity': opacity,
      'decoy': decoyImagePath,
    });
  }

  static Future<void> hide() async {
    await FlutterScreenOverlay.closeOverlay();
  }
}
