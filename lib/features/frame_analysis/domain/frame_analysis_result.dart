import 'package:equatable/equatable.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_extreme.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

/// Aggregated output of analyzing a single camera frame: both histograms,
/// the average sampled color, plus (optionally) the brightest/darkest
/// sampled regions.
class FrameAnalysisResult extends Equatable {
  const FrameAnalysisResult({
    required this.spectrum,
    required this.luminosity,
    this.averageColor,
    this.brightestRegion,
    this.darkestRegion,
  });

  final SpectrumHistogram spectrum;
  final LuminosityHistogram luminosity;

  /// Mean RGB over every sampled pixel in the frame (post color-enhance,
  /// if that setting is on - matching what the histograms themselves are
  /// built from). Null only when the frame couldn't be analyzed at all
  /// (e.g. unsupported format).
  final RgbColor? averageColor;

  /// The brightest sampled region of the frame (a luma-weighted centroid
  /// over an area, not a single pixel), or null when extreme-spot
  /// location wasn't requested or the frame couldn't be analyzed.
  final FrameExtreme? brightestRegion;

  /// The darkest sampled region of the frame. See [brightestRegion].
  final FrameExtreme? darkestRegion;

  @override
  List<Object?> get props => [
    spectrum,
    luminosity,
    averageColor,
    brightestRegion,
    darkestRegion,
  ];
}
