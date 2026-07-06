import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/data/camera_repository_impl.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_lens_direction.dart';

/// How long a transient action failure (e.g. "torch is only available on
/// the rear lens") stays visible over the live preview before it's
/// cleared automatically. Deliberately short: unlike [CameraViewModel.
/// errorMessage] (which reflects the camera being genuinely unusable),
/// this is just a toast-style notice - the preview keeps running
/// underneath it the whole time.
const Duration kTransientMessageDuration = Duration(seconds: 3);

/// Drives the Camera sector: permission handling, lens/torch control, and
/// exposing the live [CameraRepositoryImpl] for the preview widget.
class CameraViewModel extends ChangeNotifier {
  CameraViewModel({
    required CameraRepositoryImpl cameraRepository,
    required AppLogger logger,
    Duration transientMessageDuration = kTransientMessageDuration,
  }) : _cameraRepository = cameraRepository,
       _logger = logger,
       _transientMessageDuration = transientMessageDuration {
    unawaited(_initialize());
  }

  final CameraRepositoryImpl _cameraRepository;
  final AppLogger _logger;
  final Duration _transientMessageDuration;

  bool _isReady = false;
  String? _errorMessage;
  String? _transientMessage;
  Timer? _transientMessageTimer;

  CameraRepositoryImpl get repository => _cameraRepository;
  bool get isReady => _isReady;

  /// A blocking error: the camera itself can't be used at all (denied
  /// permission, no hardware, failed to open), so the preview area shows
  /// this message instead of a (non-existent) live feed.
  String? get errorMessage => _errorMessage;

  /// A transient, non-blocking notice (e.g. a rejected torch toggle) that
  /// should surface briefly *over* the still-live preview, then clear
  /// itself - see [kTransientMessageDuration].
  String? get transientMessage => _transientMessage;

  bool get isTorchOn => _cameraRepository.isTorchOn;

  /// Whether acquisition is currently paused - see [toggleFreeze].
  bool get isFrozen => _cameraRepository.isFrozen;
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
      _errorMessage = null;
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
      _errorMessage = null;
    } on CameraFailure catch (error, stackTrace) {
      _logger.error(
        'Failed to switch lens',
        error: error,
        stackTrace: stackTrace,
      );
      _showTransientMessage(error.message);
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
      // setTorchEnabled throws before flipping its internal flag, so
      // isTorchOn correctly stays false here - only the notice needs
      // showing, nothing to roll back.
      _showTransientMessage(error.message);
    } finally {
      notifyListeners();
    }
  }

  /// Pauses (or resumes) camera acquisition: the preview freezes on its
  /// last frame and the Spectrum/Luminosity charts and average color
  /// stop updating too, so the user can study the current moment
  /// without everything continuing to change underneath them.
  Future<void> toggleFreeze() async {
    try {
      await _cameraRepository.setFrozen(!isFrozen);
    } on CameraFailure catch (error, stackTrace) {
      _logger.error(
        'Failed to toggle freeze',
        error: error,
        stackTrace: stackTrace,
      );
      _showTransientMessage(error.message);
    } finally {
      notifyListeners();
    }
  }

  /// Shows [message] over the preview and schedules it to clear itself
  /// after [_transientMessageDuration], replacing any previous pending
  /// clear so a fresh message always gets its own full duration.
  void _showTransientMessage(String message) {
    _transientMessage = message;
    _transientMessageTimer?.cancel();
    _transientMessageTimer = Timer(_transientMessageDuration, () {
      _transientMessage = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _transientMessageTimer?.cancel();
    unawaited(_cameraRepository.dispose());
    super.dispose();
  }
}
