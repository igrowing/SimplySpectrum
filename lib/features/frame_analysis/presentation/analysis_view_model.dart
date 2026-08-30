import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:simply_spectrum/core/charting/axis_scale.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_repository.dart';
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analysis_result.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analyzer.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_extreme.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';
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
  bool _hasScaledAxesOnce = false;
  AppSettings _settings = const AppSettings();

  SpectrumHistogram spectrum = SpectrumHistogram.empty();
  LuminosityHistogram luminosity = LuminosityHistogram.empty();
  FramePoint? brightestPoint;
  FramePoint? darkestPoint;

  /// Mean color over the most recently analyzed frame, for the Controls
  /// sector's average-color readout. Null until the first frame is
  /// analyzed.
  RgbColor? averageColor;

  /// Full-scale occurrence count for the Spectrum chart's Y axis, only
  /// updated every [kAxisRescaleInterval] (see [_rescaleAxes]).
  int spectrumAxisMax = 1;

  /// Full-scale occurrence count for the Luminosity chart's Y axis, only
  /// updated every [kAxisRescaleInterval] (see [_rescaleAxes]).
  int luminosityAxisMax = 1;

  final _ExtremeSmoother _brightestSmoother = _ExtremeSmoother();
  final _ExtremeSmoother _darkestSmoother = _ExtremeSmoother();

  /// Called whenever the Settings screen's values change, so the next
  /// analyzed frame picks up the new options.
  set settings(AppSettings settings) {
    final wasEnabled = _settings.showExtremeLightSpots;
    final nowEnabled = settings.showExtremeLightSpots;
    _settings = settings;
    if (wasEnabled == nowEnabled) return;
    // Toggling the feature either way discards any smoothing state so a
    // stale committed region can't linger into the next enable.
    _brightestSmoother.reset();
    _darkestSmoother.reset();
    if (wasEnabled && !nowEnabled) {
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
      averageColor = result.averageColor ?? averageColor;
      if (locateExtremes) {
        _brightestSmoother.update(result.brightestRegion, bright: true);
        _darkestSmoother.update(result.darkestRegion, bright: false);
        brightestPoint = _brightestSmoother.displayed;
        darkestPoint = _darkestSmoother.displayed;
      }
      // Seed the Y-axis scale from the very first analyzed frame rather
      // than leaving it at the placeholder value of 1 until the first
      // `kAxisRescaleInterval` timer tick fires - otherwise both charts
      // would show an absurdly tall, near-flat-lined polyline for up to
      // 10 seconds after the app launches.
      if (!_hasScaledAxesOnce) {
        _hasScaledAxesOnce = true;
        _rescaleAxes();
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

/// Confirm-before-jump + EMA smoother for one extreme-light marker.
///
/// [analyzeFrame] re-runs a full global search every analysis (~2 Hz) and
/// its raw output hops between competing bright/dark regions frame to
/// frame - which the beta testers reported as the marker "jumping like
/// crazy". This holds a single *committed* region and:
///
///  * eases the marker toward the freshly detected centroid with an
///    exponential moving average while the detection stays in that region
///    (small, smooth corrections);
///  * relocates to a different region only once a challenger region has
///    persisted for [_confirmFrames] consecutive analyses, OR is
///    dramatically more extreme than the committed one (so pointing the
///    camera at a new bright light still snaps promptly).
class _ExtremeSmoother {
  /// Per-analysis fraction of the remaining distance the marker moves
  /// toward the detected centroid while staying within the committed
  /// region.
  static const double _emaAlpha = 0.35;

  /// Larger step used the frame a relocation to a new region is
  /// committed - decisive but still eased rather than an instant teleport.
  static const double _jumpAlpha = 0.6;

  /// Consecutive analyses a challenger region must win before the marker
  /// relocates to it.
  static const int _confirmFrames = 2;

  /// A challenger whose mean luma beats the committed region's by at
  /// least this much (brighter for the bright marker, darker for the
  /// dark one) is adopted immediately, skipping [_confirmFrames].
  static const double _dramaticLumaDelta = 25;

  /// Minimum [NormalizedRect.overlapFraction] (after inflating both by
  /// [_matchInflate]) for two detections to count as the same region.
  static const double _overlapToMatch = 0.25;

  /// Normalized amount each region rect is grown by before overlap
  /// testing, so a region that merely shifts by a cell still matches.
  static const double _matchInflate = 0.03;

  FramePoint? _displayed;
  NormalizedRect? _committed;
  double _committedMeanLuma = 0;
  NormalizedRect? _candidate;
  int _candidateStreak = 0;

  /// The smoothed marker position to show, or null before the first
  /// detection (or after [reset]).
  FramePoint? get displayed => _displayed;

  void reset() {
    _displayed = null;
    _committed = null;
    _committedMeanLuma = 0;
    _candidate = null;
    _candidateStreak = 0;
  }

  void update(FrameExtreme? detection, {required bool bright}) {
    if (detection == null) return; // Nothing detected: hold last position.

    final region = detection.bounds;

    if (_committed == null || _displayed == null) {
      _commit(detection, snap: true);
      return;
    }

    if (_sameRegion(_committed!, region)) {
      // Same region: track its slow drift and ease the marker in.
      _committed = NormalizedRect.lerp(_committed!, region, _emaAlpha);
      _committedMeanLuma = detection.meanLuma;
      _displayed = _lerpPoint(_displayed!, detection.point, _emaAlpha);
      _candidate = null;
      _candidateStreak = 0;
      return;
    }

    final dramatic = bright
        ? detection.meanLuma >= _committedMeanLuma + _dramaticLumaDelta
        : detection.meanLuma <= _committedMeanLuma - _dramaticLumaDelta;
    if (dramatic) {
      _commit(detection, snap: false);
      return;
    }

    if (_candidate != null && _sameRegion(_candidate!, region)) {
      _candidateStreak++;
    } else {
      _candidate = region;
      _candidateStreak = 1;
    }
    if (_candidateStreak >= _confirmFrames) {
      _commit(detection, snap: false);
    }
    // Otherwise: unconfirmed challenger - leave the marker where it is.
  }

  void _commit(FrameExtreme detection, {required bool snap}) {
    _committed = detection.bounds;
    _committedMeanLuma = detection.meanLuma;
    _displayed = (snap || _displayed == null)
        ? detection.point
        : _lerpPoint(_displayed!, detection.point, _jumpAlpha);
    _candidate = null;
    _candidateStreak = 0;
  }

  bool _sameRegion(NormalizedRect a, NormalizedRect b) =>
      a.inflated(_matchInflate).overlapFraction(b.inflated(_matchInflate)) >=
      _overlapToMatch;

  FramePoint _lerpPoint(FramePoint a, FramePoint b, double t) => FramePoint(
    normalizedX: a.normalizedX + (b.normalizedX - a.normalizedX) * t,
    normalizedY: a.normalizedY + (b.normalizedY - a.normalizedY) * t,
    luma: (a.luma + (b.luma - a.luma) * t).round(),
  );
}
