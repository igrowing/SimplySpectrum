import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/presentation/spectrum_chart_painter.dart';

void main() {
  group('nmToHz', () {
    test('400nm (violet end) is a higher frequency than 700nm (red end)', () {
      expect(nmToHz(400), greaterThan(nmToHz(700)));
    });

    test('matches c = f * lambda for a known value', () {
      // 500nm -> 3e8 / 500e-9 = 6e14 Hz.
      expect(nmToHz(500), closeTo(6e14, 1e12));
    });

    test('doubling wavelength halves frequency', () {
      final base = nmToHz(400);
      final doubled = nmToHz(800);

      expect(doubled, closeTo(base / 2, base / 2 * 0.01));
    });
  });

  group('SpectrumChartPainter', () {
    test('paints an empty histogram in both units without throwing', () {
      final painter = SpectrumChartPainter(
        histogram: SpectrumHistogram.empty(),
        unit: SpectrumUnit.wavelengthNm,
        showPeaks: true,
        yAxisMax: 1,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(200, 180)),
        returnsNormally,
      );

      final hzPainter = SpectrumChartPainter(
        histogram: SpectrumHistogram.empty(),
        unit: SpectrumUnit.frequencyHz,
        showPeaks: true,
        yAxisMax: 1,
      );
      expect(
        () => hzPainter.paint(canvas, const Size(200, 180)),
        returnsNormally,
      );
    });

    test('paints multiple close peaks (label declutter path) without '
        'throwing', () {
      final bins = List<int>.filled(SpectrumHistogram.binCount, 0);
      // A handful of tight local maxima near 500-520nm to exercise the
      // peak-label collision-avoidance loop.
      for (final index in [100, 105, 110, 115, 120]) {
        bins[index] = 20;
        bins[index - 1] = 5;
        bins[index + 1] = 5;
      }
      final painter = SpectrumChartPainter(
        histogram: SpectrumHistogram(bins: bins),
        unit: SpectrumUnit.wavelengthNm,
        showPeaks: true,
        yAxisMax: 20,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(200, 180)),
        returnsNormally,
      );
    });

    test('shouldRepaint is true only when a tracked field changes', () {
      final bins = List<int>.filled(SpectrumHistogram.binCount, 0);
      final base = SpectrumChartPainter(
        histogram: SpectrumHistogram(bins: bins),
        unit: SpectrumUnit.wavelengthNm,
        showPeaks: false,
        yAxisMax: 10,
      );
      final identical = SpectrumChartPainter(
        histogram: SpectrumHistogram(bins: bins),
        unit: SpectrumUnit.wavelengthNm,
        showPeaks: false,
        yAxisMax: 10,
      );
      final differentUnit = SpectrumChartPainter(
        histogram: SpectrumHistogram(bins: bins),
        unit: SpectrumUnit.frequencyHz,
        showPeaks: false,
        yAxisMax: 10,
      );
      final differentAxis = SpectrumChartPainter(
        histogram: SpectrumHistogram(bins: bins),
        unit: SpectrumUnit.wavelengthNm,
        showPeaks: false,
        yAxisMax: 20,
      );

      expect(identical.shouldRepaint(base), isFalse);
      expect(differentUnit.shouldRepaint(base), isTrue);
      expect(differentAxis.shouldRepaint(base), isTrue);
    });
  });
}
