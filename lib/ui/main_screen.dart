import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intruder_shield/models/app_settings.dart';
import 'package:intruder_shield/services/background_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initForegroundTask();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'intruder_shield_channel',
        channelName: 'Intruder Shield Monitor',
        channelDescription: 'Monitoring camera for intruders',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map) {
      if (data['action'] == 'SHOW_OVERLAY') {
        _showBlackOverlay();
      } else if (data['action'] == 'HIDE_OVERLAY') {
        _hideBlackOverlay();
      } else if (data['error'] != null) {
        debugPrint('Task error: ${data['error']}');
      }
    }
  }

  Future<void> _showBlackOverlay() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
    }
    await FlutterOverlayWindow.showOverlay(
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      overlayTitle: 'Intruder Shield Active',
      overlayContent: 'Screen dimmed for privacy',
      enableDrag: false,
      flag: OverlayFlag.defaultFlag,
    );
    await FlutterOverlayWindow.shareData({
      'opacity': _settings.overlayOpacity,
    });
  }

  Future<void> _hideBlackOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final overlayStatus = await Permission.systemAlertWindow.request();
    await Permission.notification.request();

    if (!mounted) return;

    if (cameraStatus.isGranted && overlayStatus.isGranted) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions are required to run the service.')),
      );
    }
  }

  Future<void> _toggleService() async {
    if (_settings.isRunning) {
      await FlutterForegroundTask.stopService();
      _settings.setRunning(false);
    } else {
      if (!await Permission.camera.isGranted) {
        await _requestPermissions();
        if (!await Permission.camera.isGranted) return;
      }
      if (!await Permission.systemAlertWindow.isGranted) {
        await _requestPermissions();
        if (!await Permission.systemAlertWindow.isGranted) return;
      }

      await FlutterForegroundTask.startService(
        serviceId: 100,
        notificationTitle: 'Intruder Shield Active',
        notificationText: 'Monitoring front camera...',
        callback: startCallback,
      );
      _settings.setRunning(true);
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _settings,
      child: Consumer<AppSettings>(
        builder: (context, settings, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Intruder Shield'),
              centerTitle: true,
            ),
            body: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    settings.isRunning ? Icons.shield : Icons.shield_outlined,
                    size: 100,
                    color: settings.isRunning ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    settings.isRunning ? 'Monitoring Active' : 'Monitoring Stopped',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  Text('Overlay Opacity: ${(settings.overlayOpacity * 100).toInt()}%'),
                  Slider(
                    value: settings.overlayOpacity,
                    min: 0.3,
                    max: 1.0,
                    onChanged: (value) {
                      settings.setOverlayOpacity(value);
                      FlutterOverlayWindow.shareData({'opacity': value});
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _requestPermissions,
                    icon: const Icon(Icons.security),
                    label: const Text('Request Permissions'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _toggleService,
                    icon: Icon(settings.isRunning ? Icons.stop : Icons.play_arrow),
                    label: Text(settings.isRunning ? 'Stop Service' : 'Start Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: settings.isRunning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
