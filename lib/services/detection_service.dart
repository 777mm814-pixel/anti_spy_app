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
        minFaceSize: 0.15, // 15% من حجم الصورة (لضمان عدم الخلط)
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
    final int width = image.width;
    final int height = image.height;

    // ✅ الحل الأول: حساب التدوير الصحيح ديناميكياً
    final sensorOrientation = camera.sensorOrientation;
    int rotationCompensation = 0; // بما أن التطبيق portraitUp
    
    int finalRotation;
    if (camera.lensDirection == CameraLensDirection.front) {
      finalRotation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      finalRotation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    
    final rotation = InputImageRotationValue.fromRawValue(finalRotation);
    if (rotation == null) return null;

    Uint8List? cleanBytes;

    if (image.format.group == ImageFormatGroup.nv21) {
      cleanBytes = _cleanNv21(image);
    } else if (image.planes.length == 3) {
      cleanBytes = _yuv420ToNv21(image);
    }

    if (cleanBytes == null || cleanBytes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: cleanBytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width, // نمرر العرض الفعلي
      ),
    );
  }

  /// ✅ الحل الثاني: دالة تنظيف NV21 تضمن إزالة أي Padding
  Uint8List? _cleanNv21(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int expectedSize = width * height * 3 ~/ 2;
      final Plane plane = image.planes.first;

      // إذا كانت البيانات مثالية، نرجعها كما هي
      if (plane.bytesPerRow == width && plane.bytes.length == expectedSize) {
        return plane.bytes;
      }

      // إذا كان هناك حشوة (Padding)، ننشئ مصفوفة نظيفة
      final Uint8List cleanBytes = Uint8List(expectedSize);
      int pos = 0;
      final int rowStride = plane.bytesPerRow;
      
      // في NV21، يتم دمج Y و VU في مصفوفة واحدة
      // مستوى Y
      for (int row = 0; row < height; row++) {
        final int start = row * rowStride;
        if (start + width <= plane.bytes.length) {
          cleanBytes.setRange(pos, pos + width, plane.bytes, start);
          pos += width;
        }
      }

      // مستوى VU
      for (int row = 0; row < height ~/ 2; row++) {
        final int start = (height + row) * rowStride;
        if (start + width <= plane.bytes.length) {
          cleanBytes.setRange(pos, pos + width, plane.bytes, start);
          pos += width;
        }
      }

      return cleanBytes;
    } catch (e) {
      return null;
    }
  }

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

      int pos = 0;
      for (int row = 0; row < height; row++) {
        final int rowStart = row * yPlane.bytesPerRow;
        for (int col = 0; col < width; col++) {
          nv21[pos++] = yPlane.bytes[rowStart + col];
        }
      }

      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 2;

      for (int row = 0; row < height ~/ 2; row++) {
        final int rowStart = row * uvRowStride;
        for (int col = 0; col < width ~/ 2; col++) {
          final int index = rowStart + col * uvPixelStride;
          if (index < vPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = vPlane.bytes[index];
          }
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
