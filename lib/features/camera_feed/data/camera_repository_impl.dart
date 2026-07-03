import 'dart:async';

import 'package:camera/camera.dart' as plugin;

import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_lens_direction.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_repository.dart';
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';

/// Concrete camera data source backed by the `camera` plugin.
///
/// Presentation code that needs to *render* the live preview should use
/// [controller] directly with `CameraPreview`. Everything else (analysis
/// pipelines, lens/torch control) should depend on the [CameraRepository]
/// abstraction.
class CameraRepositoryImpl implements CameraRepository {
  CameraRepositoryImpl({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  plugin.CameraController? _controller;
  List<plugin.CameraDescription> _availableCameras = [];
  CameraLensDirection? _currentLens;
  bool _isTorchOn = false;
  final StreamController<RawCameraFrame> _frameStreamController =
      StreamController<RawCameraFrame>.broadcast();

  /// Live controller for building a `CameraPreview` widget. Null until
  /// [initialize] has completed successfully.
  plugin.CameraController? get controller => _controller;

  @override
  Stream<RawCameraFrame> get frameStream => _frameStreamController.stream;

  @override
  CameraLensDirection? get currentLens => _currentLens;

  @override
  bool get isTorchOn => _isTorchOn;

  @override
  Future<void> initialize({
    CameraLensDirection lens = CameraLensDirection.rear,
  }) async {
    try {
      _availableCameras = _availableCameras.isNotEmpty
          ? _availableCameras
          : await plugin.availableCameras();
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to enumerate cameras',
        error: error,
        stackTrace: stackTrace,
      );
      throw CameraFailure('Unable to list device cameras: $error');
    }

    if (_availableCameras.isEmpty) {
      throw const CameraFailure('No camera hardware detected on this device');
    }

    await _open(lens);
  }

  Future<void> _open(CameraLensDirection lens) async {
    final description = _describeFor(lens);
    final previous = _controller;

    final newController = plugin.CameraController(
      description,
      plugin.ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: plugin.ImageFormatGroup.yuv420,
    );

    try {
      await newController.initialize();
      await newController.startImageStream(_onPluginFrame);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to open camera lens $lens',
        error: error,
        stackTrace: stackTrace,
      );
      await newController.dispose();
      throw CameraFailure('Unable to start camera on $lens lens: $error');
    }

    if (previous != null) {
      await previous.dispose();
    }

    _controller = newController;
    _currentLens = lens;
    _isTorchOn = false;
  }

  plugin.CameraDescription _describeFor(CameraLensDirection lens) {
    final target = lens == CameraLensDirection.rear
        ? plugin.CameraLensDirection.back
        : plugin.CameraLensDirection.front;

    return _availableCameras.firstWhere(
      (camera) => camera.lensDirection == target,
      orElse: () => _availableCameras.first,
    );
  }

  void _onPluginFrame(plugin.CameraImage image) {
    if (_frameStreamController.isClosed) return;

    try {
      _frameStreamController.add(_toRawFrame(image));
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Dropping unreadable camera frame',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  RawCameraFrame _toRawFrame(plugin.CameraImage image) {
    return RawCameraFrame(
      width: image.width,
      height: image.height,
      format: RawFrameFormat.yuv420,
      planes: image.planes
          .map(
            (plane) => RawFramePlane(
              bytes: plane.bytes,
              bytesPerRow: plane.bytesPerRow,
              pixelStride: plane.bytesPerPixel ?? 1,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> switchLens() async {
    final current = _currentLens;
    if (current == null) {
      throw const CameraFailure('Camera not initialized yet');
    }
    if (_isTorchOn) {
      await setTorchEnabled(false);
    }
    await _open(current.opposite);
  }

  @override
  Future<void> setTorchEnabled(bool enabled) async {
    final activeController = _controller;
    if (activeController == null) {
      throw const CameraFailure('Camera not initialized yet');
    }
    if (_currentLens != CameraLensDirection.rear) {
      throw const CameraFailure('Torch is only available on the rear lens');
    }
    try {
      await activeController.setFlashMode(
        enabled ? plugin.FlashMode.torch : plugin.FlashMode.off,
      );
      _isTorchOn = enabled;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle torch',
        error: error,
        stackTrace: stackTrace,
      );
      throw CameraFailure('Unable to toggle torch: $error');
    }
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _currentLens = null;
    await _frameStreamController.close();
  }
}
