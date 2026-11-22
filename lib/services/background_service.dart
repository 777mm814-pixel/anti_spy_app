import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intruder_shield/services/detection_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  // ✅ ضروري جداً: تسجيل plugins في العزل الخلفي (بدونها camera لا تعمل)
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(IntruderTaskHandler());
}

class IntruderTaskHandler extends TaskHandler {
  CameraController? _cameraController;
  DetectionService? _detectionService;
  Timer? _processingTimer;
  bool _isMonitoring = false;
  bool _isOverlayActive = false;
  int _lastProcessedMs = 0;
  int _frameCount = 0;
  int _faceDetectionCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _detectionService = DetectionService();
    await _initCamera();
    _isMonitoring = true;

    // مؤقت لتشخيص الحالة كل 10 ثوانٍ
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isMonitoring) return;
      FlutterForegroundTask.sendDataToMain({
        'action': 'DIAGNOSTIC',
        'frames': _frameCount,
        'faces': _faceDetectionCount,
        'overlayActive': _isOverlayActive,
      });
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _sendError('No cameras available');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // ✅ استخدام medium بدلاً من low (480p) لأن ML Kit يحتاج 480x360 على الأقل
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_onCameraImage);

      FlutterForegroundTask.sendDataToMain({
        'action': 'CAMERA_READY',
        'resolution':
            '${_cameraController!.value.previewSize?.width.toInt()}x${_cameraController!.value.previewSize?.height.toInt()}',
      });
    } catch (e) {
      _sendError('Camera init failed: $e');
    }
  }

  void _onCameraImage(CameraImage image) async {
    if (!_isMonitoring || _isOverlayActive) return;
    if (_detectionService == null || _cameraController == null) return;

    _frameCount++;

    // تقييد المعالجة: لا تعالج أكثر من إطار كل 800 مللي ثانية
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessedMs < 800) return;
    _lastProcessedMs = now;

    try {
      final faceCount = await _detectionService!.processCameraImage(
        image,
        _cameraController!.description,
      );

      if (faceCount > 0) {
        _faceDetectionCount++;
      }

      // إرسال نتيجة كل معالجة للواجهة (للتشخيص)
      FlutterForegroundTask.sendDataToMain({
        'action': 'FACE_RESULT',
        'count': faceCount,
        'frameSize': '${image.width}x${image.height}',
      });

      // المنطق الذكي: إذا كان هناك متطفل (وجهان أو أكثر)
      if (faceCount >= 2 && !_isOverlayActive) {
        await _handleIntruderDetected();
      }
    } catch (e) {
      _sendError('Face detection error: $e');
    }
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
      'faceCount': _faceDetectionCount,
    });

    // 3. انتظار 30 ثانية
    await Future.delayed(const Duration(seconds: 30));

    // 4. إغلاق الأوفرلاي واستئناف الكاميرا
    FlutterForegroundTask.sendDataToMain({'action': 'HIDE_OVERLAY'});
    await _resumeCamera();
    _isOverlayActive = false;
    _faceDetectionCount = 0;
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
      _sendError('Resume camera failed: $e');
    }
  }

  void _sendError(String message) {
    FlutterForegroundTask.sendDataToMain({'action': 'ERROR', 'message': message});
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
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
