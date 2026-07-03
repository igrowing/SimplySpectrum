import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';

void main() {
  group('LuminosityHistogram', () {
    test('empty histogram has null weighted averages', () {
      final histogram = LuminosityHistogram.empty();

      expect(histogram.totalOccurrences, 0);
      expect(histogram.weightedAverageLuma, isNull);
      expect(histogram.weightedAverageApproxLux, isNull);
    });

    test('weightedAverageLuma weighs bins by occurrence count', () {
      final bins = List<int>.filled(kLumaBinCount, 0);
      bins[0] = 3; // black, weight 3
      bins[255] = 1; // white, weight 1

      final histogram = LuminosityHistogram(bins: bins);

      // (0*3 + 255*1) / 4 = 63.75
      expect(histogram.weightedAverageLuma, closeTo(63.75, 0.001));
    });

    test('constructor asserts on wrong bin length', () {
      expect(
        () => LuminosityHistogram(bins: const [1, 2, 3]),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('lumaToApproxLux', () {
    test('maps 0 to 0 lux and 255 to 1000 lux linearly', () {
      expect(lumaToApproxLux(0), 0);
      expect(lumaToApproxLux(255), closeTo(1000, 0.001));
      expect(lumaToApproxLux(127.5), closeTo(500, 0.001));
    });
  });
}
