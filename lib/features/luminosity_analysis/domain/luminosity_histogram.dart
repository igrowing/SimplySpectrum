import 'package:equatable/equatable.dart';

/// Raw luma sample resolution: one bin per 8-bit luma value (0 = black,
/// 255 = white), matching the black-to-white gradient bar under the chart.
const int kLumaBinCount = 256;

/// Converts a raw 0-255 luma value into an approximate illuminance in lux.
///
/// IMPORTANT: a phone camera sensor cannot report calibrated photometric
/// lux without knowing exposure time, ISO and aperture, and without a
/// reference-light calibration pass. This mapping is a simple linear
/// placeholder (0-255 -> 0-1000 lux) so the UI can show a meaningful
/// number now; the info screen explains the approximation, and stage 2
/// (precise/RAL-grade color measurement) should replace this with a
/// calibrated model using camera exposure metadata.
double lumaToApproxLux(double luma) => (luma / 255) * 1000;

/// A per-frame occurrence histogram of raw luma values (0-255).
class LuminosityHistogram extends Equatable {
  LuminosityHistogram({required List<int> bins})
    : assert(bins.length == kLumaBinCount, 'bins must cover luma 0-255'),
      bins = List.unmodifiable(bins);

  factory LuminosityHistogram.empty() =>
      LuminosityHistogram(bins: List.filled(kLumaBinCount, 0));

  /// Occurrence count per luma value, index 0 == black, 255 == white.
  final List<int> bins;

  int get totalOccurrences => bins.fold(0, (sum, v) => sum + v);

  /// Weighted average luma: sum(luma * occurrences) / sum(occurrences).
  double? get weightedAverageLuma {
    final total = totalOccurrences;
    if (total == 0) return null;
    var weightedSum = 0.0;
    for (var i = 0; i < bins.length; i++) {
      weightedSum += i * bins[i];
    }
    return weightedSum / total;
  }

  /// Convenience: weighted average expressed as approximate lux.
  double? get weightedAverageApproxLux {
    final luma = weightedAverageLuma;
    if (luma == null) return null;
    return lumaToApproxLux(luma);
  }

  @override
  List<Object?> get props => [bins];
}
