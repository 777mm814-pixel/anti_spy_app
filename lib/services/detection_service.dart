import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
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

  Future<int> processCameraImage(CameraImage image, CameraDescription camera) async {
    final InputImage? inputImage = _inputImageFromCameraImage(
      image,
      camera,
      DeviceOrientation.portraitUp, // التطبيق يعمل بالوضع العمودي
    );

    if (inputImage == null) return 0;

    final faces = await _faceDetector.processImage(inputImage);
    return faces.length;
  }

  /// تحويل CameraImage إلى InputImage بالطريقة الرسمية
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    // 1. حساب زاوية الدوران
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

    // 2. التحقق من الصيغة
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

    // 3. التحقق من وجود مستوى واحد فقط (شرط ML Kit)
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;

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
