import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screen_overlay/flutter_screen_overlay.dart';

@pragma('vm:entry-point')
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: _OverlayView(),
  ));
}

class _OverlayView extends StatefulWidget {
  const _OverlayView();
  @override
  State<_OverlayView> createState() => _OverlayViewState();
}

class _OverlayViewState extends State<_OverlayView> {
  double opacity = 0.85;
  String? decoyPath;

  @override
  void initState() {
    super.initState();
    FlutterScreenOverlay.overlayListener.listen((event) {
      if (event is Map && event['type'] == 'privacy') {
        setState(() {
          opacity = (event['opacity'] as num?)?.toDouble() ?? 0.85;
          decoyPath = event['decoy'] as String?;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (decoyPath != null && File(decoyPath!).existsSync()) {
      return Image.file(File(decoyPath!), fit: BoxFit.cover);
    }
    return Container(color: Colors.black.withOpacity(opacity));
  }
}
