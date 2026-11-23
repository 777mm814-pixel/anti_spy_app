import 'package:camera/camera.dart';
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
    // ✅ استخدام الدالة الرسمية التي تتعامل مع جميع الأجهزة
    final InputImage? inputImage = inputImageFromCameraImage(
      cameraImage: image,
      sensorOrientation: camera.sensorOrientation,
      deviceOrientation: DeviceOrientation.portraitUp,
      cameraLensDirection: camera.lensDirection,
    );

    if (inputImage == null) return 0;

    final faces = await _faceDetector.processImage(inputImage);
    return faces.length;
  }

  void dispose() {
    _faceDetector.close();
  }
}
