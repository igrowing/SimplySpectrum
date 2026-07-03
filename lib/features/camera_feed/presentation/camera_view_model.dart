import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/data/camera_repository_impl.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_lens_direction.dart';

/// Drives the Camera sector: permission handling, lens/torch control, and
/// exposing the live [CameraRepositoryImpl] for the preview widget.
class CameraViewModel extends ChangeNotifier {
  CameraViewModel({
    required CameraRepositoryImpl cameraRepository,
    required AppLogger logger,
  }) : _cameraRepository = cameraRepository,
       _logger = logger {
    unawaited(_initialize());
  }

  final CameraRepositoryImpl _cameraRepository;
  final AppLogger _logger;

  bool _isReady = false;
  String? _errorMessage;

  CameraRepositoryImpl get repository => _cameraRepository;
  bool get isReady => _isReady;
  String? get errorMessage => _errorMessage;
  bool get isTorchOn => _cameraRepository.isTorchOn;
  CameraLensDirection? get currentLens => _cameraRepository.currentLens;

  Future<void> _initialize() async {
    final status = await ph.Permission.camera.request();
    if (!status.isGranted) {
      _errorMessage = 'Camera permission is required to use SimplySpectrum';
      notifyListeners();
      return;
    }

    try {
      await _cameraRepository.initialize();
      _isReady = true;
    } on CameraFailure catch (error, stackTrace) {
      _logger.error(
        'Camera initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage = error.message;
    } finally {
      notifyListeners();
    }
  }

  Future<void> switchLens() async {
    try {
      await _cameraRepository.switchLens();
    } on CameraFailure catch (error, stackTrace) {
      _logger.error(
        'Failed to switch lens',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage = error.message;
    } finally {
      notifyListeners();
    }
  }

  Future<void> toggleTorch() async {
    try {
      await _cameraRepository.setTorchEnabled(!isTorchOn);
    } on CameraFailure catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle torch',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage = error.message;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_cameraRepository.dispose());
    super.dispose();
  }
}
