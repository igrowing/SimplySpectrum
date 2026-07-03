import 'package:equatable/equatable.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

/// Aggregated output of analyzing a single camera frame: both histograms
/// plus (optionally) the brightest/darkest sampled points, computed in one
/// pass over the frame for efficiency.
class FrameAnalysisResult extends Equatable {
  const FrameAnalysisResult({
    required this.spectrum,
    required this.luminosity,
    this.brightestPoint,
    this.darkestPoint,
  });

  final SpectrumHistogram spectrum;
  final LuminosityHistogram luminosity;
  final FramePoint? brightestPoint;
  final FramePoint? darkestPoint;

  @override
  List<Object?> get props => [
    spectrum,
    luminosity,
    brightestPoint,
    darkestPoint,
  ];
}
