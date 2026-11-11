import 'dart:io';
import 'dart:ui'; // الإصلاح: استيراد مكتبة Size
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DetectionService {
  late final FaceDetector _detector;
  bool _isProcessing = false;

  DetectionService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableTracking: false,
        minFaceSize: 0.1,
      ),
    );
  }

  Future<List<Face>> detectFaces(CameraImage image, CameraDescription camera) async {
    if (_isProcessing) return [];
    _isProcessing = true;

    try {
      final inputImage = _convertToInputImage(image, camera);
      if (inputImage == null) return [];
      final faces = await _detector.processImage(inputImage);
      return faces;
    } catch (e) {
      debugPrint('Detection error: $e');
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertToInputImage(CameraImage image, CameraDescription camera) {
    try {
      if (Platform.isAndroid) {
        final format = InputImageFormatValue.fromRawValue(image.format.raw);
        if (format == null) return null;
        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: _getRotation(camera.sensorOrientation),
            format: format,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      } else if (Platform.isIOS) {
        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: _getRotation(camera.sensorOrientation),
            format: InputImageFormat.bgra8888,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      }
      return null;
    } catch (e) {
      debugPrint('Conversion error: $e');
      return null;
    }
  }

  InputImageRotation _getRotation(int orientation) {
    switch (orientation) {
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default: return InputImageRotation.rotation0deg;
    }
  }

  Future<void> dispose() async {
    await _detector.close();
  }
}
