import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:simply_spectrum/core/charting/axis_scale.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_repository.dart';
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analysis_result.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analyzer.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

/// How often new camera frames are actually analyzed and the
/// Spectrum/Luminosity charts and point overlays redraw. Camera frames
/// arrive much faster than this (15-30fps); gating analysis to this
/// interval keeps the UI feeling live while the charts stay readable
/// instead of flickering on every single frame.
const Duration kAnalysisInterval = Duration(milliseconds: 500);

/// How often the Y-axis scale (the "full-height" occurrence count used
/// to normalize and label the Spectrum/Luminosity charts) is allowed to
/// change. Deliberately slower than [kAnalysisInterval] so the axis
/// labels stay legible instead of rescaling on every chart update.
const Duration kAxisRescaleInterval = Duration(seconds: 10);

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
/// the UI thread, at most once per [kAnalysisInterval], exposing the
/// latest spectrum/luminosity histograms, their Y-axis scales, and
/// points of interest to the presentation layer.
///
/// A time-gated busy-flag throttle (rather than analyzing every frame)
/// means the chart update rate is a deliberate, predictable cadence
/// rather than however fast the camera happens to stream frames.
class AnalysisViewModel extends ChangeNotifier {
  AnalysisViewModel({
    required CameraRepository cameraRepository,
    Duration analysisInterval = kAnalysisInterval,
    Duration axisRescaleInterval = kAxisRescaleInterval,
  }) : _cameraRepository = cameraRepository,
       _analysisInterval = analysisInterval {
    _subscription = _cameraRepository.frameStream.listen(_onFrame);
    _axisRescaleTimer = Timer.periodic(
      axisRescaleInterval,
      (_) => _rescaleAxes(),
    );
  }

  final CameraRepository _cameraRepository;
  final Duration _analysisInterval;
  StreamSubscription<RawCameraFrame>? _subscription;
  Timer? _axisRescaleTimer;
  bool _isBusy = false;
  DateTime? _lastAnalysisTime;
  AppSettings _settings = const AppSettings();

  SpectrumHistogram spectrum = SpectrumHistogram.empty();
  LuminosityHistogram luminosity = LuminosityHistogram.empty();
  FramePoint? brightestPoint;
  FramePoint? darkestPoint;

  /// Full-scale occurrence count for the Spectrum chart's Y axis, only
  /// updated every [kAxisRescaleInterval] (see [_rescaleAxes]).
  int spectrumAxisMax = 1;

  /// Full-scale occurrence count for the Luminosity chart's Y axis, only
  /// updated every [kAxisRescaleInterval] (see [_rescaleAxes]).
  int luminosityAxisMax = 1;

  /// Called whenever the Settings screen's values change, so the next
  /// analyzed frame picks up the new options.
  set settings(AppSettings settings) {
    final wasEnabled = _settings.showExtremeLightSpots;
    _settings = settings;
    if (wasEnabled && !settings.showExtremeLightSpots) {
      brightestPoint = null;
      darkestPoint = null;
      notifyListeners();
    }
  }

  Future<void> _onFrame(RawCameraFrame frame) async {
    if (_isBusy) return;
    final now = DateTime.now();
    if (_lastAnalysisTime != null &&
        now.difference(_lastAnalysisTime!) < _analysisInterval) {
      return;
    }
    _isBusy = true;
    _lastAnalysisTime = now;
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
      if (locateExtremes) {
        brightestPoint = result.brightestPoint ?? brightestPoint;
        darkestPoint = result.darkestPoint ?? darkestPoint;
      }
      notifyListeners();
    } finally {
      _isBusy = false;
    }
  }

  /// Fired on [kAxisRescaleInterval]: recomputes each chart's Y-axis
  /// full-scale value from the current histogram, rounded to a legible
  /// "nice" number. Chart data itself keeps updating every
  /// [kAnalysisInterval] via [_onFrame] - only the axis scale/labels are
  /// held steady between rescales.
  void _rescaleAxes() {
    final spectrumMax = spectrum.bins.fold(0, (max, v) => v > max ? v : max);
    final luminosityMax = luminosity.bins.fold(
      0,
      (max, v) => v > max ? v : max,
    );
    spectrumAxisMax = niceAxisMax(spectrumMax);
    luminosityAxisMax = niceAxisMax(luminosityMax);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _axisRescaleTimer?.cancel();
    super.dispose();
  }
}
