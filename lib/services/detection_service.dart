import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DetectionService {
  late final FaceDetector _faceDetector;

  DetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.05, // تصغير الحجم قليلاً لضمان اكتشاف الوجوه
      ),
    );
  }

  Future<int> processCameraImage(CameraImage image, CameraDescription camera) async {
    final InputImage? inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) return 0;

    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces.length;
    } catch (e) {
      return 0;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isAndroid) {
      // التطبيق يعمل في الوضع العمودي دائماً (portraitUp = 0)
      int rotationCompensation = 0; 
      
      int finalRotation;
      if (camera.lensDirection == CameraLensDirection.front) {
        finalRotation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        finalRotation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(finalRotation);
    } else if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (rotation == null) return null;

    // إذا كانت الصورة NV21 (مستوى واحد)
    if (image.planes.length == 1) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } 
    // إذا كانت الصورة YUV420 (ثلاثة مستويات) - وهي الأكثر شيوعاً
    else if (image.planes.length == 3) {
      final nv21Bytes = _yuv420ToNv21(image);
      if (nv21Bytes.isEmpty) return null;

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width, // العرض الفعلي لأننا نظفنا البيانات
        ),
      );
    }

    return null;
  }

  /// تحويل دقيق جداً من YUV420 إلى NV21
  Uint8List _yuv420ToNv21(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final ySize = width * height;
      final uvSize = ySize ~/ 4;
      final nv21 = Uint8List(ySize + uvSize * 2);

      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      int pos = 0;

      // 1. نسخ مستوى Y
      for (int row = 0; row < height; row++) {
        final rowStart = row * yPlane.bytesPerRow;
        for (int col = 0; col < width; col++) {
          nv21[pos++] = yPlane.bytes[rowStart + col];
        }
      }

      // 2. نسخ مستوى VU (متشابك)
      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 2;

      for (int row = 0; row < height ~/ 2; row++) {
        final rowStart = row * uvRowStride;
        for (int col = 0; col < width ~/ 2; col++) {
          final index = rowStart + col * uvPixelStride;
          if (index < vPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = vPlane.bytes[index]; // V
          }
          if (index < uPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = uPlane.bytes[index]; // U
          }
        }
      }
      return nv21;
    } catch (_) {
      return Uint8List(0);
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
