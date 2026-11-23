import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intruder_shield/models/app_settings.dart';
import 'package:intruder_shield/services/background_service.dart';
import 'package:intruder_shield/services/detection_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final _settings = AppSettings();
  final List<String> _logs = [];

  CameraController? _cameraController;
  DetectionService? _detectionService;
  Timer? _frameTimer;
  int _lastProcessedMs = 0;
  bool _isMonitoring = false;
  bool _isOverlayActive = false;
  int _frameCount = 0;

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
      if (_logs.length > 30) _logs.removeLast();
    });
  }

  void _onReceiveTaskData(Object data) {
    if (data is! Map) return;
  }

  Future<void> _startCameraMonitoring() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _addLog('❌ لا توجد كاميرات متاحة');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // نطلب YUV420 لأنها الأكثر توافقاً مع أجهزة الأندرويد
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      _detectionService ??= DetectionService();
      _isMonitoring = true;
      _frameCount = 0;

      await _cameraController!.startImageStream(_onCameraImage);
      _addLog('📷 الكاميرا جاهزة (${_cameraController!.value.previewSize?.width.toInt()}x${_cameraController!.value.previewSize?.height.toInt()})');

      _frameTimer?.cancel();
      _frameTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (!_isMonitoring) return;
        _addLog('📊 المراقبة نشطة | Overlay: $_isOverlayActive');
      });
    } catch (e) {
      _addLog('❌ فشل تشغيل الكاميرا: $e');
    }
  }

  void _onCameraImage(CameraImage image) async {
    if (!_isMonitoring || _isOverlayActive) return;
    if (_detectionService == null || _cameraController == null) return;

    _frameCount++;

    // سجل تشخيصي لأول 3 إطارات فقط
    if (_frameCount <= 3) {
      _addLog('📸 ${image.format.group} | ${image.planes.length} planes | ${image.width}x${image.height}');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessedMs < 800) return;
    _lastProcessedMs = now;

    try {
      final faceCount = await _detectionService!.processCameraImage(
        image,
        _cameraController!.description,
      );

      if (!mounted) return;

      // سجل النتيجة كل 5 إطارات
      if (_frameCount % 5 == 0) {
        _addLog('👁️ وجوه: $faceCount | إطار: ${image.width}x${image.height}');
      }

      if (faceCount >= 2 && !_isOverlayActive) {
        await _handleIntruderDetected();
      }
    } catch (e) {
      if (_frameCount <= 3) {
        _addLog('❌ خطأ في الكشف: $e');
      }
    }
  }

  Future<void> _handleIntruderDetected() async {
    _isOverlayActive = true;
    _addLog('🚨 متطفل detected! جاري إيقاف الكاميرا...');

    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (_) {}

    await _showBlackOverlay();
    await Future.delayed(const Duration(seconds: 30));
    await _hideBlackOverlay();
    await _resumeCamera();

    _isOverlayActive = false;
    _addLog('✅ انتهى التنبيه، عادت المراقبة');
  }

  Future<void> _resumeCamera() async {
    try {
      if (_cameraController != null) {
        if (!_cameraController!.value.isInitialized) {
          await _cameraController!.initialize();
        }
        if (!_cameraController!.value.isStreamingImages) {
          await _cameraController!.startImageStream(_onCameraImage);
        }
      }
    } catch (e) {
      _addLog('❌ فشل استئناف الكاميرا: $e');
    }
  }

  Future<void> _stopCameraMonitoring() async {
    _isMonitoring = false;
    _frameTimer?.cancel();
    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController?.dispose();
      _cameraController = null;
    } catch (_) {}
    _detectionService?.dispose();
    _detectionService = null;
    _addLog('🛑 تم إيقاف الكاميرا');
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
    await FlutterOverlayWindow.shareData({'opacity': _settings.overlayOpacity});
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
          const SnackBar(content: Text('Permissions are required.')),
        );
      }
    }
  }

  Future<void> _toggleService() async {
    if (_settings.isRunning) {
      await _stopCameraMonitoring();
      await FlutterForegroundTask.stopService();
      _settings.setRunning(false);
      _addLog('🛑 تم إيقاف الخدمة');
    } else {
      if (!await Permission.camera.isGranted ||
          !await Permission.systemAlertWindow.isGranted) {
        await _requestPermissions();
        if (!await Permission.camera.isGranted) return;
        if (!await Permission.systemAlertWindow.isGranted) return;
      }

      await FlutterForegroundTask.startService(
        serviceId: 100,
        notificationTitle: 'Intruder Shield Active',
        notificationText: 'Monitoring front camera...',
        callback: startCallback,
      );

      await _startCameraMonitoring();

      _settings.setRunning(true);
      _addLog('▶️ تم بدء الخدمة والكاميرا');
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _stopCameraMonitoring();
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
