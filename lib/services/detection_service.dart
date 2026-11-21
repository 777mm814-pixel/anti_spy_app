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
        minFaceSize: 0.1,
      ),
    );
  }

  Future<int> processCameraImage(CameraImage image, CameraDescription camera) async {
    final inputImage = _convertToInputImage(image, camera);
    if (inputImage == null) return 0;
    final faces = await _faceDetector.processImage(inputImage);
    return faces.length;
  }

  InputImage? _convertToInputImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation rotation;
    if (sensorOrientation == 90 || sensorOrientation == 270) {
      rotation = InputImageRotation.rotation90deg;
    } else {
      rotation = InputImageRotation.rotation0deg;
    }

    final bytes = _yuv420ToNv21(image);
    if (bytes.isEmpty) return null;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.width,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;
    int pos = 0;
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final int yIndex = row * yRowStride + col * yPixelStride;
        if (yIndex < yPlane.bytes.length) {
          nv21[pos++] = yPlane.bytes[yIndex];
        }
      }
    }

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 2;
    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uvIndex = row * uvRowStride + col * uvPixelStride;
        if (uvIndex < vPlane.bytes.length && pos < nv21.length) {
          nv21[pos++] = vPlane.bytes[uvIndex];
        }
        if (uvIndex < uPlane.bytes.length && pos < nv21.length) {
          nv21[pos++] = uPlane.bytes[uvIndex];
        }
      }
    }

    return nv21;
  }

  void dispose() {
    _faceDetector.close();
  }
}
