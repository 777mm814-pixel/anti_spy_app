import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DetectionService {
  late final FaceDetector _detector;
  bool _isProcessing = false;
  DateTime _lastProcessTime = DateTime.now();

  DetectionService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableTracking: false,
        minFaceSize: 0.1,
      ),
    );
  }

  Future<List<Face>> detectFaces(CameraImage image, CameraDescription camera) async {
    // 1. منع المعالجة المتزامنة
    if (_isProcessing) return [];
    
    // 2. تقييد المعدل: تأكد من مرور 300 مللي ثانية على الأقل
    final now = DateTime.now();
    if (now.difference(_lastProcessTime).inMilliseconds < 300) return [];
    
    _isProcessing = true;
    _lastProcessTime = now;

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
        if (image.planes.length == 3) {
          final nv21Bytes = _yuv420ToNv21(image);
          return InputImage.fromBytes(
            bytes: nv21Bytes,
            metadata: InputImageMetadata(
              size: Size(image.width.toDouble(), image.height.toDouble()),
              rotation: _getRotation(camera.sensorOrientation),
              format: InputImageFormat.nv21,
              bytesPerRow: image.planes[0].bytesPerRow,
            ),
          );
        } else if (image.planes.length == 1) {
          return InputImage.fromBytes(
            bytes: image.planes[0].bytes,
            metadata: InputImageMetadata(
              size: Size(image.width.toDouble(), image.height.toDouble()),
              rotation: _getRotation(camera.sensorOrientation),
              format: InputImageFormat.nv21,
              bytesPerRow: image.planes[0].bytesPerRow,
            ),
          );
        }
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

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = (width * height) ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    final yBuffer = yPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;

    int pos = 0;
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final index = row * yRowStride + col * yPixelStride;
        nv21[pos++] = yBuffer[index];
      }
    }

    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 2;

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final uvIndex = row * uvRowStride + col * uvPixelStride;
        nv21[pos++] = vBuffer[uvIndex];
        nv21[pos++] = uBuffer[uvIndex];
      }
    }
    return nv21;
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
