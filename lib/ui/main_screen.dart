import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

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
          Text('Overlay Opacity: ${(s.overlayOpacity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: s.overlayOpacity, min: 0.2, max: 1.0,
            onChanged: (v) => context.read<AppSettings>().setOpacity(v),
          ),
          Text('Sensor Sensitivity: ${(s.sensitivity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: s.sensitivity, min: 0.1, max: 1.0,
            onChanged: (v) => context.read<AppSettings>().setSensitivity(v),
          ),
          SwitchListTile(
            title: const Text('Decoy / Camouflage Mode'),
            value: s.decoyEnabled,
            onChanged: (v) => context.read<AppSettings>().setDecoy(v),
          ),
          SwitchListTile(
            title: const Text('Silent Haptic Alert'),
            value: s.hapticEnabled,
            onChanged: (v) => context.read<AppSettings>().setHaptic(v),
          ),
        ],
      ),
    );
  }
}
