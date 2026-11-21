import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intruder_shield/services/detection_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(IntruderTaskHandler());
}

class IntruderTaskHandler extends TaskHandler {
  CameraController? _cameraController;
  DetectionService? _detectionService;
  Timer? _processingTimer;
  bool _isMonitoring = false;
  bool _isOverlayActive = false;
  int _lastProcessedMs = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _detectionService = DetectionService();
    await _initCamera();
    _isMonitoring = true;
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      if (!_isMonitoring || _isOverlayActive) return;
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_onCameraImage);
    } catch (e) {
      FlutterForegroundTask.sendDataToMain({'error': 'Camera init failed: $e'});
    }
  }

  void _onCameraImage(CameraImage image) async {
    if (!_isMonitoring || _isOverlayActive) return;
    if (_detectionService == null || _cameraController == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessedMs < 800) return;
    _lastProcessedMs = now;

    try {
      final faceCount = await _detectionService!.processCameraImage(
        image,
        _cameraController!.description,
      );
      if (faceCount >= 2 && !_isOverlayActive) {
        await _handleIntruderDetected();
      }
    } catch (_) {}
  }

  Future<void> _handleIntruderDetected() async {
    _isOverlayActive = true;

    // 1. إيقاف بث الكاميرا فوراً لتحرير موارد المعالج (منع ANR)
    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (_) {}

    // 2. إرسال إشارة للواجهة لفتح الأوفرلاي
    FlutterForegroundTask.sendDataToMain({
      'action': 'SHOW_OVERLAY',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // 3. انتظار 30 ثانية (المدة التي تظهر فيها الشاشة السوداء)
    await Future.delayed(const Duration(seconds: 30));

    // 4. إغلاق الأوفرلاي واستئناف الكاميرا
    FlutterForegroundTask.sendDataToMain({'action': 'HIDE_OVERLAY'});
    await _resumeCamera();
    _isOverlayActive = false;
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
      FlutterForegroundTask.sendDataToMain({'error': 'Resume camera failed: $e'});
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // يتم استدعاؤها كل 5 ثوانٍ حسب إعدادات الخدمة
    if (!_isMonitoring && !_isOverlayActive) {
      _initCamera();
      _isMonitoring = true;
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['action'] == 'STOP') {
      _isMonitoring = false;
      _processingTimer?.cancel();
      _cameraController?.dispose();
      _cameraController = null;
      _detectionService?.dispose();
      _detectionService = null;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _isMonitoring = false;
    _processingTimer?.cancel();
    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController?.dispose();
    } catch (_) {}
    _detectionService?.dispose();
    _detectionService = null;
  }
}
