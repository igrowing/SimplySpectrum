import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

void main() {
  group('SpectrumHistogram', () {
    test('empty histogram has null weighted average and no peaks', () {
      final histogram = SpectrumHistogram.empty();

      expect(histogram.totalOccurrences, 0);
      expect(histogram.weightedAverageNm, isNull);
      expect(histogram.detectPeaks(), isEmpty);
    });

    test('weightedAverageNm weighs bins by occurrence count', () {
      final bins = List<int>.filled(SpectrumHistogram.binCount, 0);
      // index 0 -> 400nm, index 100 -> 500nm.
      bins[0] = 1;
      bins[100] = 3;
      final histogram = SpectrumHistogram(bins: bins);

      // (400*1 + 500*3) / 4 = 475
      expect(histogram.weightedAverageNm, 475);
    });

    test('detectPeaks finds local maxima and caps at maxPeaks', () {
      final bins = List<int>.filled(SpectrumHistogram.binCount, 0);
      // Craft 6 well-separated single-bin spikes, each a local maximum.
      for (final i in [10, 40, 70, 100, 130, 160]) {
        bins[i] = 5 + i;
      }
      final histogram = SpectrumHistogram(bins: bins);

      final peaks = histogram.detectPeaks();

      expect(peaks.length, 5);
      // Sorted by occurrence descending - the highest-index spike (160)
      // has the highest crafted value (5 + 160).
      expect(peaks.first.wavelengthNm, histogram.nmForBinIndex(160));
    });

    test('detectPeaks ignores flat/noise bins below minOccurrences', () {
      final bins = List<int>.filled(SpectrumHistogram.binCount, 0);
      bins[50] = 1;
      final histogram = SpectrumHistogram(bins: bins);

      expect(histogram.detectPeaks(minOccurrences: 2), isEmpty);
    });

    test('constructor asserts on wrong bin length', () {
      expect(
        () => SpectrumHistogram(bins: const [1, 2, 3]),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
