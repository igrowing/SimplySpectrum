import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_repository.dart';
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analysis_result.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analyzer.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

class _AnalyzeArgs {
  const _AnalyzeArgs({
    required this.frame,
    required this.enhanceColors,
    required this.locateBrightestPoint,
    required this.locateDarkestPoint,
  });

  final RawCameraFrame frame;
  final bool enhanceColors;
  final bool locateBrightestPoint;
  final bool locateDarkestPoint;
}

// Top-level so it can be sent to `compute`'s background isolate.
FrameAnalysisResult _analyzeFrameIsolateEntry(_AnalyzeArgs args) =>
    analyzeFrame(
      args.frame,
      enhanceColors: args.enhanceColors,
      locateBrightestPoint: args.locateBrightestPoint,
      locateDarkestPoint: args.locateDarkestPoint,
    );

/// Subscribes to the live camera frame stream and runs [analyzeFrame] off
/// the UI thread for each frame, exposing the latest spectrum/luminosity
/// histograms and points of interest to the presentation layer.
///
/// A busy-flag throttle (rather than a fixed timer) means we always
/// analyze the most recently available frame and never queue up stale
/// work - the chart naturally settles to the device's real analysis rate.
class AnalysisViewModel extends ChangeNotifier {
  AnalysisViewModel({required CameraRepository cameraRepository})
    : _cameraRepository = cameraRepository {
    _subscription = _cameraRepository.frameStream.listen(_onFrame);
  }

  final CameraRepository _cameraRepository;
  StreamSubscription<RawCameraFrame>? _subscription;
  bool _isBusy = false;
  AppSettings _settings = const AppSettings();

  SpectrumHistogram spectrum = SpectrumHistogram.empty();
  LuminosityHistogram luminosity = LuminosityHistogram.empty();
  FramePoint? brightestPoint;
  FramePoint? darkestPoint;

  /// Called whenever the Settings sector's values change, so the next
  /// analyzed frame picks up the new options.
  set settings(AppSettings settings) {
    _settings = settings;
  }

  Future<void> _onFrame(RawCameraFrame frame) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      final result = await compute(
        _analyzeFrameIsolateEntry,
        _AnalyzeArgs(
          frame: frame,
          enhanceColors: _settings.enhanceColors,
          locateBrightestPoint: _settings.showBrightestPoint,
          locateDarkestPoint: _settings.showDarkestPoint,
        ),
      );
      spectrum = result.spectrum;
      luminosity = result.luminosity;
      brightestPoint = result.brightestPoint;
      darkestPoint = result.darkestPoint;
      notifyListeners();
    } finally {
      _isBusy = false;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
