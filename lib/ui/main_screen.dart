import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_settings.dart';
import '../models/locale_provider.dart';
import '../utils/app_strings.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _overlayStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final cam = await Permission.camera.status;
    final overlay = await Permission.systemAlertWindow.status;
    if (!mounted) return;
    setState(() {
      _cameraStatus = cam;
      _overlayStatus = overlay;
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraStatus = status);
  }

  Future<void> _requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    if (!mounted) return;
    setState(() => _overlayStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get(context, 'app_title')),
        actions: [
          // زر تغيير اللغة
          IconButton(
            icon: const Icon(Icons.translate),
            tooltip: 'Change Language',
            onPressed: () => localeProvider.toggleLocale(),
          ),
          // زر تغيير الثيم
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
          _buildPermissionCard(
            title: AppStrings.get(context, _cameraStatus.isGranted ? 'camera_perm_granted' : _cameraStatus.isPermanentlyDenied ? 'camera_perm_denied' : 'camera_perm_required'),
            status: _cameraStatus,
            onRequest: _requestCameraPermission,
            buttonText: AppStrings.get(context, 'request_camera_perm'),
          ),
          const SizedBox(height: 12),
          _buildPermissionCard(
            title: AppStrings.get(context, _overlayStatus.isGranted ? 'overlay_perm_granted' : _overlayStatus.isPermanentlyDenied ? 'overlay_perm_denied' : 'overlay_perm_required'),
            status: _overlayStatus,
            onRequest: _requestOverlayPermission,
            buttonText: AppStrings.get(context, 'request_overlay_perm'),
          ),
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
          Text('${AppStrings.get(context, 'overlay_opacity')}: ${(s.overlayOpacity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: s.overlayOpacity, min: 0.2, max: 1.0,
            onChanged: (v) => context.read<AppSettings>().setOpacity(v),
          ),
          Text('${AppStrings.get(context, 'sensor_sensitivity')}: ${(s.sensitivity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: s.sensitivity, min: 0.1, max: 1.0,
            onChanged: (v) => context.read<AppSettings>().setSensitivity(v),
          ),
          SwitchListTile(
            title: Text(AppStrings.get(context, 'decoy_mode')),
            value: s.decoyEnabled,
            onChanged: (v) => context.read<AppSettings>().setDecoy(v),
          ),
          SwitchListTile(
            title: Text(AppStrings.get(context, 'haptic_alert')),
            subtitle: Text(AppStrings.get(context, 'haptic_subtitle')),
            value: s.hapticEnabled,
            onChanged: (v) => context.read<AppSettings>().setHaptic(v),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required PermissionStatus status,
    required VoidCallback onRequest,
    required String buttonText,
  }) {
    final bool isGranted = status.isGranted;
    final bool isPermanentlyDenied = status.isPermanentlyDenied;

    return Card(
      elevation: 4,
      color: isGranted ? Colors.green.shade900 : Colors.red.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(isGranted ? Icons.check_circle : Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isGranted && !isPermanentlyDenied)
              ElevatedButton(onPressed: onRequest, child: Text(buttonText)),
            if (isPermanentlyDenied)
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: Text(AppStrings.get(context, 'open_settings')),
              ),
          ],
        ),
      ),
    );
  }
}
