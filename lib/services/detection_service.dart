import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DetectionService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableTracking: false,
      minFaceSize: 0.1,
    ),
  );

  bool _busy = false;

  Future<bool> hasIntruder(CameraImage image, CameraDescription camera, double sensitivity) async {
    if (_busy) return false;
    _busy = true;
    try {
      final input = _toInputImage(image, camera);
      if (input == null) { _busy = false; return false; }
      final faces = await _detector.processImage(input);
      _busy = false;
      if (faces.isEmpty) return false;
      final face = faces.first;
      final box = face.boundingBox;
      final imageArea = image.width * image.height;
      final faceArea = box.width * box.height;
      final ratio = faceArea / imageArea;
      final threshold = 0.08 - (sensitivity * 0.05);
      return ratio >= threshold;
    } catch (_) {
      _busy = false;
      return false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    final plane = image.planes.first;
    final rotation = _rotationFor(camera.sensorOrientation);
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation _rotationFor(int orientation) {
    switch (orientation) {
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default: return InputImageRotation.rotation0deg;
    }
  }

  void dispose() => _detector.close();
}
