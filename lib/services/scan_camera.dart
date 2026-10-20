import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Why the in-app camera cannot be shown.
enum ScanCameraProblem { noCamera, permissionDenied, failed }

class ScanCameraException implements Exception {
  const ScanCameraException(this.problem);

  final ScanCameraProblem problem;
}

/// The live camera used by the Scan screen. Tests replace it with a fake.
abstract interface class ScanCamera {
  /// Opens the back camera; throws [ScanCameraException] when it cannot.
  Future<void> initialize();

  Widget buildPreview();

  /// Preview width / height in portrait.
  double get aspectRatio;

  bool get hasFlash;

  Future<void> setTorch(bool on);

  /// Focuses and meters on [point], from (0, 0) at the preview's top left to
  /// (1, 1) at its bottom right, in portrait. Does nothing where the camera
  /// cannot.
  Future<void> focusAt(Offset point);

  /// Takes a photo and returns the path of the saved file.
  Future<String> takePicture();

  Future<void> pause();

  Future<void> resume();

  Future<void> dispose();
}

typedef ScanCameraFactory = ScanCamera Function();

/// The phone's back camera through the official camera plugin.
class DeviceScanCamera implements ScanCamera {
  CameraController? _controller;
  bool _hasFlash = false;

  CameraController get _ready {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const ScanCameraException(ScanCameraProblem.failed);
    }
    return controller;
  }

  @override
  Future<void> initialize() async {
    try {
      // Listing cameras never needs the user, so a stuck platform call is
      // treated as no camera instead of spinning forever. Opening the camera
      // below is not limited: the permission dialog may take a while.
      final cameras =
          await availableCameras().timeout(const Duration(seconds: 10));
      if (cameras.isEmpty) {
        throw const ScanCameraException(ScanCameraProblem.noCamera);
      }
      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        // 1080p. "high" is only 720p, which looked soft on the preview and
        // in the photo; the model reads 224x224, so larger buys nothing.
        ResolutionPreset.veryHigh,
        // Photos only: the app never asks for the microphone.
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
        _hasFlash = true;
      } on CameraException {
        _hasFlash = false;
      }
    } on ScanCameraException {
      rethrow;
    } on CameraException catch (error) {
      throw ScanCameraException(error.code.startsWith('CameraAccess')
          ? ScanCameraProblem.permissionDenied
          : ScanCameraProblem.failed);
    } catch (_) {
      // Also covers platforms without the plugin, such as widget tests.
      throw const ScanCameraException(ScanCameraProblem.noCamera);
    }
  }

  @override
  Widget buildPreview() => CameraPreview(_ready);

  @override
  double get aspectRatio {
    final ratio = _ready.value.aspectRatio;
    // The plugin reports landscape width / height; the screen is portrait.
    return ratio > 1 ? 1 / ratio : ratio;
  }

  @override
  bool get hasFlash => _hasFlash;

  @override
  Future<void> setTorch(bool on) =>
      _ready.setFlashMode(on ? FlashMode.torch : FlashMode.off);

  @override
  Future<void> focusAt(Offset point) async {
    final controller = _ready;
    try {
      if (controller.value.focusPointSupported) {
        await controller.setFocusPoint(point);
      }
      if (controller.value.exposurePointSupported) {
        await controller.setExposurePoint(point);
      }
    } on CameraException {
      // Focus stays automatic; not worth interrupting the user.
    }
  }

  @override
  Future<String> takePicture() async => (await _ready.takePicture()).path;

  @override
  Future<void> pause() async => _controller?.pausePreview();

  @override
  Future<void> resume() async => _controller?.resumePreview();

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
