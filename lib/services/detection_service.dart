import 'dart:io';
import 'dart:typed_data';
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
        enableTracking: true,
        minFaceSize: 0.05,
      ),
    );
  }

  Future<int> processCameraImage(
      CameraImage image, CameraDescription camera) async {
    final InputImage? inputImage =
        _inputImageFromCameraImage(image, camera, DeviceOrientation.portraitUp);

    if (inputImage == null) return 0;

    final faces = await _faceDetector.processImage(inputImage);
    return faces.length;
  }

  /// تحويل CameraImage إلى InputImage مع دعم YUV420 و NV21
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;

      int finalRotation;
      if (camera.lensDirection == CameraLensDirection.front) {
        finalRotation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        finalRotation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(finalRotation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // ─── الحالة 1: الصورة أصلاً NV21 (مستوى واحد) ───
    if (format == InputImageFormat.nv21 && image.planes.length == 1) {
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

    // ─── الحالة 2: الصورة YUV420 (ثلاثة مستويات) ───
    // هذه هي الحالة الشائعة على أندرويد، نقوم بتحويلها إلى NV21
    if (image.planes.length == 3) {
      final nv21Bytes = _yuv420ToNv21(image);
      if (nv21Bytes == null) return null;

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

    return null;
  }

  /// تحويل YUV420 (ثلاثة مستويات) إلى NV21 (مستوى واحد)
  /// الخوارزمية مأخوذة من كود Google MLKit الرسمي
  Uint8List? _yuv420ToNv21(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int imageSize = width * height;
      final int uvSize = imageSize ~/ 4;

      final Uint8List nv21 = Uint8List(imageSize + uvSize * 2);

      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      // 1. نسخ مستوى Y كاملاً
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

      // 2. دمج V و U بالتناوب (NV21 = VU VU VU ...)
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 2;

      for (int row = 0; row < height ~/ 2; row++) {
        final int rowStart = row * uvRowStride;
        for (int col = 0; col < width ~/ 2; col++) {
          final int index = rowStart + col * uvPixelStride;
          if (index < vPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = vPlane.bytes[index]; // V أولاً
          }
          if (index < uPlane.bytes.length && pos < nv21.length) {
            nv21[pos++] = uPlane.bytes[index]; // ثم U
          }
        }
      }

      return nv21;
    } catch (e) {
      return null;
    }
  }

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  void dispose() {
    _faceDetector.close();
  }
}
