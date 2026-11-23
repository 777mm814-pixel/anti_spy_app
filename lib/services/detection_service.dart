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

    // ✅ NV21: مستوى واحد فقط، تمرير مباشر بدون تحويل
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

    // ⚠️ Fallback: إذا أعاد الجهاز YUV420 (3 مستويات) لأي سبب
    return null;
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
