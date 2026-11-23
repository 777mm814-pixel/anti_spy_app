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
        enableTracking: false, // تعطيل التتبع لتقليل استهلاك الموارد ومنع التعليق
        minFaceSize: 0.05,
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
      // تجاهل خطأ الإطار الواحد حتى لا يتوقف التطبيق
      return 0;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    // 1. حساب الدوران الصحيح
    final sensorOrientation = camera.sensorOrientation;
    int finalRotation;
    
    if (camera.lensDirection == CameraLensDirection.front) {
      finalRotation = (sensorOrientation + 0) % 360; // portraitUp
    } else {
      finalRotation = (sensorOrientation - 0 + 360) % 360;
    }
    
    final rotation = InputImageRotationValue.fromRawValue(finalRotation);
    if (rotation == null) return null;

    // 2. الحصول على بيانات NV21 نظيفة (بدون Padding)
    Uint8List? nv21Bytes;
    
    if (image.format.group == ImageFormatGroup.nv21) {
      nv21Bytes = _cleanNv21(image);
    } else if (image.format.group == ImageFormatGroup.yuv420) {
      nv21Bytes = _yuv420ToNv21(image);
    }

    if (nv21Bytes == null || nv21Bytes.isEmpty) return null;

    // 3. تمرير البيانات النظيفة مع العرض الصحيح
    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width, // نمرر العرض الفعلي وليس rowStride
      ),
    );
  }

  /// دالة إزالة الحشوة (Padding) من NV21
  Uint8List? _cleanNv21(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final plane = image.planes.first;
      final expectedSize = width * height * 3 ~/ 2;
      
      // إذا كانت البيانات مثالية، نرجعها كما هي
      if (plane.bytesPerRow == width && plane.bytes.length == expectedSize) {
        return plane.bytes;
      }
      
      // إذا كان هناك حشوة، نقوم بإنشاء مصفوفة جديدة ونسخ البيانات الصافية
      final cleanBytes = Uint8List(expectedSize);
      int pos = 0;
      
      // نسخ مستوى Y
      for (int i = 0; i < height; i++) {
        int start = i * plane.bytesPerRow;
        if (start + width <= plane.bytes.length) {
          cleanBytes.setRange(pos, pos + width, plane.bytes, start);
          pos += width;
        }
      }
      
      // نسخ مستوى VU
      for (int i = 0; i < height ~/ 2; i++) {
        int start = (height + i) * plane.bytesPerRow;
        if (start + width <= plane.bytes.length) {
          cleanBytes.setRange(pos, pos + width, plane.bytes, start);
          pos += width;
        }
      }
      
      return cleanBytes;
    } catch (_) {
      return null;
    }
  }

  /// دالة التحويل من YUV420 إلى NV21 (كاحتياط)
  Uint8List? _yuv420ToNv21(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final expectedSize = width * height * 3 ~/ 2;
      final nv21 = Uint8List(expectedSize);

      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final yRowStride = yPlane.bytesPerRow;
      final yPixelStride = yPlane.bytesPerPixel ?? 1;

      int pos = 0;
      for (int row = 0; row < height; row++) {
        final rowStart = row * yRowStride;
        for (int col = 0; col < width; col++) {
          final index = rowStart + col * yPixelStride;
          if (index < yPlane.bytes.length) {
            nv21[pos++] = yPlane.bytes[index];
          }
        }
      }

      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 2;

      for (int row = 0; row < height ~/ 2; row++) {
        final rowStart = row * uvRowStride;
        for (int col = 0; col < width ~/ 2; col++) {
          final index = rowStart + col * uvPixelStride;
          if (index < vPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = vPlane.bytes[index];
          }
          if (index < uPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = uPlane.bytes[index];
          }
        }
      }
      return nv21;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
