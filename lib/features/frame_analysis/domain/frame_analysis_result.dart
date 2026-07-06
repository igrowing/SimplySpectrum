import 'package:equatable/equatable.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

/// Aggregated output of analyzing a single camera frame: both histograms,
/// the average sampled color, plus (optionally) the brightest/darkest
/// sampled points - all computed in one pass over the frame for
/// efficiency.
class FrameAnalysisResult extends Equatable {
  const FrameAnalysisResult({
    required this.spectrum,
    required this.luminosity,
    this.averageColor,
    this.brightestPoint,
    this.darkestPoint,
  });

  final SpectrumHistogram spectrum;
  final LuminosityHistogram luminosity;

  /// Mean RGB over every sampled pixel in the frame (post color-enhance,
  /// if that setting is on - matching what the histograms themselves are
  /// built from). Null only when the frame couldn't be analyzed at all
  /// (e.g. unsupported format).
  final RgbColor? averageColor;
  final FramePoint? brightestPoint;
  final FramePoint? darkestPoint;

  @override
  List<Object?> get props => [
    spectrum,
    luminosity,
    averageColor,
    brightestPoint,
    darkestPoint,
  ];
}
