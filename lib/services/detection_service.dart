import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
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
        minFaceSize: 0.08, // ✅ تقليل الحجم لاكتشاف الوجوه الأبعد
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
      // في حال فشل الإطار، نعيد 0 ولا ننهار
      return 0;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final int width = image.width;
    final int height = image.height;

    // ✅ حساب التدوير الصحيح للكاميرا الأمامية
    // للكاميرا الأمامية في الوضع العمودي، نحتاج غالباً إلى 270 درجة
    final sensorOrientation = camera.sensorOrientation;
    int finalRotation;
    if (camera.lensDirection == CameraLensDirection.front) {
      // الكاميرا الأمامية: إضافة 270 درجة للوضع العمودي
      finalRotation = (sensorOrientation + 270) % 360;
    } else {
      // الكاميرا الخلفية: إضافة 90 درجة
      finalRotation = (sensorOrientation + 90) % 360;
    }
    
    final rotation = InputImageRotationValue.fromRawValue(finalRotation);
    if (rotation == null) return null;

    // ✅ دالة التحويل الصارمة (تتعامل مع padding و pixelStride)
    final Uint8List? nv21Bytes = _yuv420ToNv21(image);
    if (nv21Bytes == null || nv21Bytes.isEmpty) return null;

    // التأكد من أن حجم المصفوفة مطابق تماماً للمطلوب
    final expectedSize = width * height * 3 ~/ 2;
    if (nv21Bytes.length != expectedSize) {
      return null; // لا تمرر بيانات فاسدة إلى ML Kit
    }

    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width, // العرض الفعلي لأننا نظفنا البيانات
      ),
    );
  }

  /// تحويل YUV420 (3 planes) إلى NV21 (1 plane) بشكل صارم
  /// يعتمد على rowStride و pixelStride لكل مستوى
  Uint8List? _yuv420ToNv21(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int ySize = width * height;
      final int uvSize = ySize ~/ 4;
      final Uint8List nv21 = Uint8List(ySize + uvSize * 2);

      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      // 1. نسخ مستوى Y مع مراعاة rowStride و pixelStride
      final int yRowStride = yPlane.bytesPerRow;
      final int yPixelStride = yPlane.bytesPerPixel ?? 1;
      int pos = 0;

      for (int row = 0; row < height; row++) {
        final int rowStart = row * yRowStride;
        for (int col = 0; col < width; col++) {
          final int index = rowStart + col * yPixelStride;
          if (index < yPlane.bytes.length) {
            nv21[pos++] = yPlane.bytes[index];
          }
        }
      }

      // 2. نسخ مستوى V و U بالتناوب (NV21 = VU VU VU...)
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 2;

      for (int row = 0; row < height ~/ 2; row++) {
        final int rowStart = row * uvRowStride;
        for (int col = 0; col < width ~/ 2; col++) {
          final int index = rowStart + col * uvPixelStride;
          
          // V أولاً
          if (index < vPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = vPlane.bytes[index];
          }
          // ثم U
          if (index < uPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = uPlane.bytes[index];
          }
        }
      }

      return nv21;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
