import 'package:equatable/equatable.dart';

import 'package:simply_spectrum/features/spectrum_analysis/domain/wavelength_color_table.dart';

/// A single detected local peak on the spectrum histogram.
class SpectrumPeak extends Equatable {
  const SpectrumPeak({required this.wavelengthNm, required this.occurrences});

  final double wavelengthNm;
  final int occurrences;

  @override
  List<Object?> get props => [wavelengthNm, occurrences];
}

/// A 1nm-resolution occurrence histogram of detected wavelengths across the
/// visible spectrum (400-700nm), built from one analyzed camera frame.
class SpectrumHistogram extends Equatable {
  SpectrumHistogram({required List<int> bins})
    : assert(
        bins.length ==
            (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm).toInt() + 1,
        'bins must cover 400-700nm at 1nm resolution',
      ),
      bins = List.unmodifiable(bins);

  factory SpectrumHistogram.empty() =>
      SpectrumHistogram(bins: List.filled(binCount, 0));

  /// Occurrence count per 1nm bin, index 0 == 400nm.
  final List<int> bins;

  static int get binCount =>
      (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm).toInt() + 1;

  double nmForBinIndex(int index) => kMinVisibleWavelengthNm + index;

  int get totalOccurrences => bins.fold(0, (sum, v) => sum + v);

  /// Weighted average wavelength: sum(nm * occurrences) / sum(occurrences).
  /// Returns null when the frame produced no chromatic samples at all.
  double? get weightedAverageNm {
    final total = totalOccurrences;
    if (total == 0) return null;
    var weightedSum = 0.0;
    for (var i = 0; i < bins.length; i++) {
      weightedSum += nmForBinIndex(i) * bins[i];
    }
    return weightedSum / total;
  }

  /// Detects up to [maxPeaks] prominent local maxima (a bin strictly higher
  /// than both immediate neighbors, with a minimum occurrence count so flat
  /// noise doesn't register as a peak), sorted by prominence descending.
  List<SpectrumPeak> detectPeaks({
    int maxPeaks = 5,
    int minOccurrences = 1,
  }) {
    final candidates = <SpectrumPeak>[];
    for (var i = 1; i < bins.length - 1; i++) {
      final value = bins[i];
      if (value < minOccurrences) continue;
      if (value > bins[i - 1] && value > bins[i + 1]) {
        candidates.add(
          SpectrumPeak(wavelengthNm: nmForBinIndex(i), occurrences: value),
        );
      }
    }
    candidates.sort((a, b) => b.occurrences.compareTo(a.occurrences));
    return candidates.take(maxPeaks).toList(growable: false);
  }

  @override
  List<Object?> get props => [bins];
}
