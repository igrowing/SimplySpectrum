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

/// How often the smoothed brightest/darkest overlay points are allowed to
/// move on screen. The underlying detection still runs on every frame -
/// only the on-screen position is throttled and averaged, since a raw
/// per-frame point jitters distractingly even though each individual
/// sample is accurate.
const Duration kExtremePointUpdateInterval = Duration(milliseconds: 500);

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

/// Running mean of a stream of [FramePoint]s collected between two
/// on-screen updates, so the displayed point is a smoothed average of
/// every frame sampled in that window rather than a single noisy sample.
class _PointAccumulator {
  double _sumX = 0;
  double _sumY = 0;
  int _sumLuma = 0;
  int _count = 0;

  void add(FramePoint point) {
    _sumX += point.normalizedX;
    _sumY += point.normalizedY;
    _sumLuma += point.luma;
    _count++;
  }

  /// The mean point accumulated so far, or null if nothing was added.
  /// Does not reset the accumulator - call [reset] once it's been read.
  FramePoint? get average {
    if (_count == 0) return null;
    return FramePoint(
      normalizedX: _sumX / _count,
      normalizedY: _sumY / _count,
      luma: (_sumLuma / _count).round(),
    );
  }

  void reset() {
    _sumX = 0;
    _sumY = 0;
    _sumLuma = 0;
    _count = 0;
  }
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
  AnalysisViewModel({
    required CameraRepository cameraRepository,
    Duration extremePointUpdateInterval = kExtremePointUpdateInterval,
  }) : _cameraRepository = cameraRepository {
    _subscription = _cameraRepository.frameStream.listen(_onFrame);
    _pointUpdateTimer = Timer.periodic(
      extremePointUpdateInterval,
      (_) => _publishSmoothedPoints(),
    );
  }

  final CameraRepository _cameraRepository;
  StreamSubscription<RawCameraFrame>? _subscription;
  Timer? _pointUpdateTimer;
  bool _isBusy = false;
  AppSettings _settings = const AppSettings();

  final _PointAccumulator _brightestAccumulator = _PointAccumulator();
  final _PointAccumulator _darkestAccumulator = _PointAccumulator();

  SpectrumHistogram spectrum = SpectrumHistogram.empty();
  LuminosityHistogram luminosity = LuminosityHistogram.empty();
  FramePoint? brightestPoint;
  FramePoint? darkestPoint;

  /// Called whenever the Settings screen's values change, so the next
  /// analyzed frame picks up the new options.
  set settings(AppSettings settings) {
    final wasEnabled = _settings.showExtremeLightSpots;
    _settings = settings;
    if (wasEnabled && !settings.showExtremeLightSpots) {
      brightestPoint = null;
      darkestPoint = null;
      _brightestAccumulator.reset();
      _darkestAccumulator.reset();
      notifyListeners();
    }
  }

  Future<void> _onFrame(RawCameraFrame frame) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      final locateExtremes = _settings.showExtremeLightSpots;
      final result = await compute(
        _analyzeFrameIsolateEntry,
        _AnalyzeArgs(
          frame: frame,
          enhanceColors: _settings.enhanceColors,
          locateBrightestPoint: locateExtremes,
          locateDarkestPoint: locateExtremes,
        ),
      );
      spectrum = result.spectrum;
      luminosity = result.luminosity;
      if (result.brightestPoint != null) {
        _brightestAccumulator.add(result.brightestPoint!);
      }
      if (result.darkestPoint != null) {
        _darkestAccumulator.add(result.darkestPoint!);
      }
      notifyListeners();
    } finally {
      _isBusy = false;
    }
  }

  /// Fired on [kExtremePointUpdateInterval]: moves the on-screen
  /// brightest/darkest markers to the average of every sample collected
  /// since the last tick, then clears the accumulators for the next
  /// window. Chart data (spectrum/luminosity) is untouched here - it
  /// keeps updating every frame via [_onFrame].
  void _publishSmoothedPoints() {
    if (!_settings.showExtremeLightSpots) return;
    final nextBrightest = _brightestAccumulator.average;
    final nextDarkest = _darkestAccumulator.average;
    _brightestAccumulator.reset();
    _darkestAccumulator.reset();
    if (nextBrightest == null && nextDarkest == null) return;
    brightestPoint = nextBrightest ?? brightestPoint;
    darkestPoint = nextDarkest ?? darkestPoint;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _pointUpdateTimer?.cancel();
    super.dispose();
  }
}
