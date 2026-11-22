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
        enableTracking: true, // يساعد على استقرار الاكتشاف بين الإطارات
        minFaceSize: 0.05,     // يسمح باكتشاف وجوه أصغر
      ),
    );
  }

  Future<int> processCameraImage(CameraImage image, CameraDescription camera) async {
    final inputImage = _convertToInputImage(image, camera);
    if (inputImage == null) return 0;

    final faces = await _faceDetector.processImage(inputImage);
    return faces.length;
  }

  /// تحويل CameraImage (YUV_420_888) إلى InputImage (NV21) بشكل صحيح
  InputImage? _convertToInputImage(CameraImage image, CameraDescription camera) {
    // 1. حساب الدوران الصحيح (مع مراعاة الكاميرا الأمامية)
    final rotation = _getRotation(camera);

    // 2. تحويل YUV_420_888 إلى NV21 مع احترام rowStride و pixelStride
    final nv21Bytes = _yuv420ToNv21(image);
    if (nv21Bytes == null || nv21Bytes.isEmpty) return null;

    // 3. بناء InputImage
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.width,
    );

    return InputImage.fromBytes(bytes: nv21Bytes, metadata: metadata);
  }

  /// الدوران الصحيح: للكاميرا الأمامية غالباً 270، للخلفية 90
  InputImageRotation _getRotation(CameraDescription camera) {
    final sensor = camera.sensorOrientation;
    if (camera.lensDirection == CameraLensDirection.front) {
      // الكاميرا الأمامية: دوران 270 (أو 90 مع مرآة)
      switch (sensor) {
        case 90:
          return InputImageRotation.rotation270deg;
        case 270:
          return InputImageRotation.rotation90deg;
        default:
          return InputImageRotation.rotation0deg;
      }
    } else {
      // الكاميرا الخلفية
      switch (sensor) {
        case 90:
          return InputImageRotation.rotation90deg;
        case 270:
          return InputImageRotation.rotation270deg;
        default:
          return InputImageRotation.rotation0deg;
      }
    }
  }

  /// تحويل YUV_420_888 إلى NV21 (Y + VU المتداخل) مع احترام strides
  Uint8List? _yuv420ToNv21(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int ySize = width * height;
      final int uvSize = ySize ~/ 2;
      final Uint8List nv21 = Uint8List(ySize + uvSize);

      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      // 1. نسخ Y مع مراعاة rowStride و pixelStride
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

      // 2. نسخ V ثم U بالتناوب (NV21 = VU VU VU...)
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 2;
      final int uvHeight = height ~/ 2;
      final int uvWidth = width ~/ 2;

      for (int row = 0; row < uvHeight; row++) {
        final int rowStart = row * uvRowStride;
        for (int col = 0; col < uvWidth; col++) {
          final int index = rowStart + col * uvPixelStride;
          // V أولاً (NV21)
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
