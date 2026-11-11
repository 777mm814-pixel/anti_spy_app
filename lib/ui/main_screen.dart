import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_settings.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  PermissionStatus _cameraStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() => _cameraStatus = status);
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraStatus = status);
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
          _buildPermissionCard(),
          const SizedBox(height: 24),
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
            subtitle: const Text('Vibration permission is granted at install'),
            value: s.hapticEnabled,
            onChanged: (v) => context.read<AppSettings>().setHaptic(v),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    final bool isGranted = _cameraStatus.isGranted;
    final bool isPermanentlyDenied = _cameraStatus.isPermanentlyDenied;

    return Card(
      elevation: 4,
      color: isGranted ? Colors.green.shade900 : Colors.red.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isGranted ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isGranted
                        ? 'تم منح إذن الكاميرا'
                        : isPermanentlyDenied
                            ? 'الإذن مرفوض نهائياً، افتح الإعدادات'
                            : 'إذن الكاميرا مطلوب',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isGranted && !isPermanentlyDenied)
              ElevatedButton(
                onPressed: _requestCameraPermission,
                child: const Text('طلب إذن الكاميرا'),
              ),
            if (isPermanentlyDenied)
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: const Text('فتح إعدادات التطبيق'),
              ),
          ],
        ),
      ),
    );
  }
}
