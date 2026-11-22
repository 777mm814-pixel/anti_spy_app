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
  final List<String> _logs = [];

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

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $message');
      if (_logs.length > 20) _logs.removeLast();
    });
  }

  void _onReceiveTaskData(Object data) {
    if (data is! Map) return;

    switch (data['action']) {
      case 'SHOW_OVERLAY':
        _addLog('🚨 متطفل detected! وجهان أو أكثر (count: ${data['faceCount']})');
        _showBlackOverlay();
        break;
      case 'HIDE_OVERLAY':
        _addLog('✅ إغلاق الأوفرلاي واستئناف المراقبة');
        _hideBlackOverlay();
        break;
      case 'CAMERA_READY':
        _addLog('📷 الكاميرا جاهزة (${data['resolution']})');
        break;
      case 'FACE_RESULT':
        _addLog('👁️ وجوه: ${data['count']} | إطار: ${data['frameSize']}');
        break;
      case 'DIAGNOSTIC':
        _addLog('📊 إطارات: ${data['frames']} | اكتشافات: ${data['faces']} | Overlay: ${data['overlayActive']}');
        break;
      case 'ERROR':
        _addLog('❌ خطأ: ${data['message']}');
        break;
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
      _addLog('✅ جميع الأذونات ممنوحة');
    } else {
      _addLog('⚠️ بعض الأذونات مفقودة');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions are required to run the service.')),
        );
      }
    }
  }

  Future<void> _toggleService() async {
    if (_settings.isRunning) {
      await FlutterForegroundTask.stopService();
      _settings.setRunning(false);
      _addLog('🛑 تم إيقاف الخدمة');
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
      _addLog('▶️ تم بدء الخدمة، في انتظار الكاميرا...');
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    settings.isRunning ? Icons.shield : Icons.shield_outlined,
                    size: 80,
                    color: settings.isRunning ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    settings.isRunning ? 'المراقبة نشطة' : 'المراقبة متوقفة',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text('شفافية الأوفرلاي: ${(settings.overlayOpacity * 100).toInt()}%'),
                  Slider(
                    value: settings.overlayOpacity,
                    min: 0.3,
                    max: 1.0,
                    onChanged: (value) {
                      settings.setOverlayOpacity(value);
                      FlutterOverlayWindow.shareData({'opacity': value});
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _requestPermissions,
                          icon: const Icon(Icons.security, size: 18),
                          label: const Text('الأذونات'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleService,
                          icon: Icon(
                            settings.isRunning ? Icons.stop : Icons.play_arrow,
                            size: 18,
                          ),
                          label: Text(settings.isRunning ? 'إيقاف' : 'تشغيل'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: settings.isRunning ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // سجل التشخيص
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📋 سجل التشخيص:',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                return Text(
                                  _logs[index],
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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
