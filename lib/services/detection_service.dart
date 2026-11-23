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
        minFaceSize: 0.1, // زيادة الحجم قليلاً لتسريع الاكتشاف
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
    // 1. حساب الدوران (Rotation) بدقة
    final sensorOrientation = camera.sensorOrientation;
    int finalRotation;
    
    // للكاميرا الأمامية، التدوير غالباً يكون 270 درجة للوضع العمودي
    if (camera.lensDirection == CameraLensDirection.front) {
      finalRotation = (sensorOrientation + 270) % 360; 
    } else {
      finalRotation = (sensorOrientation + 90) % 360;
    }
    
    final rotation = InputImageRotationValue.fromRawValue(finalRotation);
    if (rotation == null) return null;

    // 2. تحويل الصورة (YUV420 -> NV21) 
    // نستخدم yuv420 كطلب أساسي لأنه يعمل على كل الأجهزة
    Uint8List nv21Bytes = _yuv420ToNv21(image);
    
    if (nv21Bytes.isEmpty) return null;

    // 3. تمرير البيانات لـ ML Kit
    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width, 
      ),
    );
  }

  /// دالة تحويل قوية جداً من YUV420 إلى NV21 تعمل على جميع المعالجات
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 4;
    final Uint8List nv21 = Uint8List(ySize + uvSize * 2);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    // نسخ مستوى Y
    int pos = 0;
    for (int row = 0; row < height; row++) {
      final int rowStart = row * yPlane.bytesPerRow;
      for (int col = 0; col < width; col++) {
        nv21[pos++] = yPlane.bytes[rowStart + col];
      }
    }

    // نسخ مستوى V و U متداخلين (VU VU VU)
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 2;

    for (int row = 0; row < height ~/ 2; row++) {
      final int rowStart = row * uvRowStride;
      for (int col = 0; col < width ~/ 2; col++) {
        final int index = rowStart + col * uvPixelStride;
        if (index < vPlane.bytes.length && pos < nv21.length) {
          nv21[pos++] = vPlane.bytes[index]; // V
        }
        if (index < uPlane.bytes.length && pos < nv21.length) {
          nv21[pos++] = uPlane.bytes[index]; // U
        }
      }
    }
    return nv21;
  }

  void dispose() {
    _faceDetector.close();
  }
}
