import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screen_overlay/flutter_screen_overlay.dart';
import '../models/app_settings.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  Future<void> _requestOverlayPermission(BuildContext context) async {
    try {
      final granted = await FlutterScreenOverlay.isPermissionGranted();
      if (!granted) {
        await FlutterScreenOverlay.requestPermission();
      }
    } catch (e) {
      debugPrint('Overlay permission request failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intruder Shield'),
        actions: [
          IconButton(
            icon: Icon(s.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              context.read<AppSettings>().setTheme(
                s.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: () => context.read<AppSettings>().setPower(!s.powerOn),
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.powerOn ? Colors.green : Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: (s.powerOn ? Colors.green : Colors.redAccent).withValues(alpha: 0.4),
                      blurRadius: 20,
                    )
                  ],
                ),
                child: Icon(
                  s.powerOn ? Icons.shield : Icons.shield_outlined,
                  color: Colors.white, size: 56,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _label('Overlay Opacity: ${(s.overlayOpacity * 100).round()}%'),
          Slider(
            value: s.overlayOpacity, min: 0.2, max: 1.0,
            onChanged: (v) => context.read<AppSettings>().setOpacity(v),
          ),
          _label('Sensor Sensitivity: ${(s.sensitivity * 100).round()}%'),
          Slider(
            value: s.sensitivity, min: 0.1, max: 1.0,
            onChanged: (v) => context.read<AppSettings>().setSensitivity(v),
          ),
          SwitchListTile(
            title: const Text('Decoy / Camouflage Mode'),
            subtitle: const Text('Show a custom image to the intruder'),
            value: s.decoyEnabled,
            onChanged: (v) => context.read<AppSettings>().setDecoy(v),
          ),
          ListTile(
            title: const Text('Choose Decoy Image'),
            trailing: const Icon(Icons.image),
            onTap: () async {
              final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (!context.mounted) return;
              if (picked != null) {
                context.read<AppSettings>().setDecoyImage(picked.path);
              }
            },
          ),
          SwitchListTile(
            title: const Text('Silent Haptic Alert'),
            subtitle: const Text('Vibrate lightly when an intruder is detected'),
            value: s.hapticEnabled,
            onChanged: (v) => context.read<AppSettings>().setHaptic(v),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _requestOverlayPermission(context),
            icon: const Icon(Icons.security),
            label: const Text('طلب إذن الظهور فوق التطبيقات'),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}
