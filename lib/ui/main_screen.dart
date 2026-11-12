import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter_screen_overlay/flutter_screen_overlay.dart';
import '../models/app_settings.dart';
import '../models/locale_provider.dart';
import '../utils/app_strings.dart';
import '../services/detection_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  final DetectionService _detectionService = DetectionService();
  bool _isDetecting = false;
  bool _hasIntruder = false;
  int _faceCount = 0;
  bool _isOverlayActive = false;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _overlayStatus = PermissionStatus.denied;
  bool _isRequestingPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toggleOverlay(false);
    _stopCamera();
    _detectionService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      final s = context.read<AppSettings>();
      if (s.powerOn) _startCameraAndDetect();
    }
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
    if (_isRequestingPermissions) return;
    _isRequestingPermissions = true;
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      setState(() => _cameraStatus = status);
    } finally {
      _isRequestingPermissions = false;
    }
  }

  Future<void> _requestOverlayPermission() async {
    if (_isRequestingPermissions) return;
    _isRequestingPermissions = true;
    try {
      final status = await Permission.systemAlertWindow.request();
      if (!mounted) return;
      setState(() => _overlayStatus = status);
    } finally {
      _isRequestingPermissions = false;
    }
  }

  Future<void> _toggleOverlay(bool show) async {
    if (!_overlayStatus.isGranted) {
      debugPrint('Overlay permission not granted, requesting...');
      await _requestOverlayPermission();
      if (!_overlayStatus.isGranted) return;
    }

    try {
      if (show && !_isOverlayActive) {
        // التأكد من الإذن الفعلي عبر الحزمة
        final has = await FlutterScreenOverlay.isPermissionGranted();
        if (!has) {
          await FlutterScreenOverlay.requestPermission();
          final granted = await FlutterScreenOverlay.isPermissionGranted();
          if (!granted) {
            debugPrint('Overlay permission still not granted after request');
            return;
          }
        }

        // تسخين المحرك لتقليل زمن الظهور
        await FlutterScreenOverlay.warmUp();

        await FlutterScreenOverlay.showOverlay(
          height: WindowSize.matchParent,
          width: WindowSize.matchParent,
          alignment: OverlayAlignment.center,
          flag: OverlayFlag.defaultFlag,
          overlayTitle: 'Intruder Shield',
          overlayContent: 'Privacy protection active',
          enableDrag: false,
        );
        _isOverlayActive = true;
        debugPrint('Overlay shown successfully');

        await Future.delayed(const Duration(milliseconds: 200));

        if (!mounted) return;
        final s = context.read<AppSettings>();
        await FlutterScreenOverlay.shareData({
          'type': 'privacy',
          'opacity': s.overlayOpacity,
        });
        debugPrint('Opacity sent: ${s.overlayOpacity}');
      } else if (!show && _isOverlayActive) {
        await FlutterScreenOverlay.closeOverlay();
        _isOverlayActive = false;
        debugPrint('Overlay closed');
      }
    } on PlatformException catch (e) {
      // الإصلاح: تسجيل رمز الخطأ بدلاً من الفشل الصامت
      debugPrint('Overlay PlatformException: code=${e.code}, message=${e.message}');
      if (e.code == 'SERVICE_START') {
        debugPrint('FGS start failed — check battery optimization or FOREGROUND_SERVICE_SPECIAL_USE');
      }
    } catch (e) {
      debugPrint('Overlay error: $e');
    }
  }

  Future<void> _startCameraAndDetect() async {
    if (_cameraStatus != PermissionStatus.granted) {
      await _requestCameraPermission();
      if (_cameraStatus != PermissionStatus.granted) return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});

      _cameraController!.startImageStream((CameraImage image) async {
        if (_isDetecting) return;
        _isDetecting = true;

        final faces = await _detectionService.detectFaces(image, frontCamera);
        if (!mounted) { _isDetecting = false; return; }

        final newHasIntruder = faces.length >= 2;

        setState(() {
          _faceCount = faces.length;
          _hasIntruder = newHasIntruder;
        });

        if (newHasIntruder != _isOverlayActive) {
          await _toggleOverlay(newHasIntruder);
        }

        _isDetecting = false;
      });
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
      if (mounted) setState(() {});
    }
  }

  void _togglePower(AppSettings s) {
    final newPower = !s.powerOn;
    context.read<AppSettings>().setPower(newPower);

    if (newPower) {
      _startCameraAndDetect();
    } else {
      _stopCamera();
      _toggleOverlay(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get(context, 'app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate),
            onPressed: () => localeProvider.toggleLocale(),
          ),
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
            title: AppStrings.get(context, _cameraStatus.isGranted ? 'camera_perm_granted' : 'camera_perm_required'),
            status: _cameraStatus,
            onRequest: _requestCameraPermission,
            buttonText: AppStrings.get(context, 'request_camera_perm'),
          ),
          const SizedBox(height: 8),
          _buildPermissionCard(
            title: AppStrings.get(context, _overlayStatus.isGranted ? 'overlay_perm_granted' : 'overlay_perm_required'),
            status: _overlayStatus,
            onRequest: _requestOverlayPermission,
            buttonText: AppStrings.get(context, 'request_overlay_perm'),
          ),
          const SizedBox(height: 20),

          if (_cameraController != null && _cameraController!.value.isInitialized)
            Center(
              child: Container(
                width: 240,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _hasIntruder ? Colors.red : Colors.green,
                    width: 4,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CameraPreview(_cameraController!),
              ),
            ),

          const SizedBox(height: 20),

          if (s.powerOn)
            Center(
              child: Column(
                children: [
                  Text(
                    'عدد الوجوه المكتشفة: $_faceCount',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasIntruder ? '⚠️ تحذير: تم رصد شخص آخر!' : '✅ أنت فقط في الإطار',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _hasIntruder ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => _togglePower(s),
              child: Container(
                width: 100, height: 100,
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
                  color: Colors.white, size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text('${AppStrings.get(context, 'overlay_opacity')}: ${(s.overlayOpacity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: s.overlayOpacity, min: 0.2, max: 1.0,
            onChanged: (v) {
              context.read<AppSettings>().setOpacity(v);
              if (_isOverlayActive) {
                FlutterScreenOverlay.shareData({
                  'type': 'privacy',
                  'opacity': v,
                });
              }
            },
          ),
          Text('${AppStrings.get(context, 'sensor_sensitivity')}: ${(s.sensitivity * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: s.sensitivity, min: 0.1, max: 1.0,
            onChanged: (v) => context.read<AppSettings>().setSensitivity(v),
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
    return Card(
      color: isGranted ? Colors.green.shade900 : Colors.red.shade900,
      child: ListTile(
        leading: Icon(isGranted ? Icons.check_circle : Icons.error, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
        trailing: isGranted ? null : TextButton(
          onPressed: onRequest,
          child: Text(buttonText, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
