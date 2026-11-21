import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayEntryWidget extends StatefulWidget {
  const OverlayEntryWidget({super.key});

  @override
  State<OverlayEntryWidget> createState() => _OverlayEntryWidgetState();
}

class _OverlayEntryWidgetState extends State<OverlayEntryWidget> {
  double _opacity = 0.95;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && event.containsKey('opacity')) {
        setState(() {
          _opacity = (event['opacity'] as num).toDouble().clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: _opacity), // ✅ الإصلاح هنا
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_off, color: Colors.white38, size: 60),
              SizedBox(height: 16),
              Text(
                'Intruder Shield',
                style: TextStyle(color: Colors.white38, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
