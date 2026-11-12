import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
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
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _overlayStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _detectionService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
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
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraStatus = status);
  }

  Future<void> _requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    if (!mounted) return;
    setState(() => _overlayStatus = status);
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

      // ترقية الدقة إلى High لرؤية أوضح للتفاصيل والوجوه البعيدة
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
        
        if (!mounted) {
          _isDetecting = false;
          return;
        }

        setState(() {
          _faceCount = faces.length;
          // المنطق الجديد: المتطفل هو أي وجه إضافي غير المستخدم الرئيسي
          _hasIntruder = _faceCount >= 2;
        });

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
