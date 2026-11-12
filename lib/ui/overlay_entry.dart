import 'package:flutter/material.dart';
import 'package:flutter_screen_overlay/flutter_screen_overlay.dart';

@pragma('vm:entry-point')
void overlayMain() {
  runApp(const OverlayApp());
}

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  double _opacity = 0.85;

  @override
  void initState() {
    super.initState();
    FlutterScreenOverlay.overlayListener.listen((event) {
      if (!mounted) return;
      if (event is Map && event['type'] == 'privacy') {
        setState(() {
          _opacity = (event['opacity'] as num?)?.toDouble() ?? 0.85;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: Container(
            color: Colors.black.withValues(alpha: _opacity),
          ),
        ),
      ),
    );
  }
}
