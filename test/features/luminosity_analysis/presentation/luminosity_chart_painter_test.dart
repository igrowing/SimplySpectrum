import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/luminosity_analysis/presentation/luminosity_chart_painter.dart';

void main() {
  group('LuminosityChartPainter', () {
    test('paints an empty histogram without throwing', () {
      final painter = LuminosityChartPainter(
        histogram: LuminosityHistogram.empty(),
        yAxisMax: 1,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(200, 150)),
        returnsNormally,
      );
    });

    test('paints a populated histogram without throwing', () {
      final bins = List<int>.filled(kLumaBinCount, 0);
      bins[128] = 40;
      final painter = LuminosityChartPainter(
        histogram: LuminosityHistogram(bins: bins),
        yAxisMax: 40,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(200, 150)),
        returnsNormally,
      );
    });

    test('shouldRepaint is true when the histogram changes', () {
      final bins = List<int>.filled(kLumaBinCount, 0);
      final oldPainter = LuminosityChartPainter(
        histogram: LuminosityHistogram(bins: bins),
        yAxisMax: 10,
      );
      final changedBins = List<int>.from(bins)..[0] = 5;
      final newPainter = LuminosityChartPainter(
        histogram: LuminosityHistogram(bins: changedBins),
        yAxisMax: 10,
      );

      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });

    test('shouldRepaint is true when only yAxisMax changes', () {
      final bins = List<int>.filled(kLumaBinCount, 0);
      final oldPainter = LuminosityChartPainter(
        histogram: LuminosityHistogram(bins: bins),
        yAxisMax: 10,
      );
      final newPainter = LuminosityChartPainter(
        histogram: LuminosityHistogram(bins: bins),
        yAxisMax: 20,
      );

      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });

    test('shouldRepaint is false when nothing changed', () {
      final bins = List<int>.filled(kLumaBinCount, 0);
      final oldPainter = LuminosityChartPainter(
        histogram: LuminosityHistogram(bins: bins),
        yAxisMax: 10,
      );
      final newPainter = LuminosityChartPainter(
        histogram: LuminosityHistogram(bins: bins),
        yAxisMax: 10,
      );

      expect(newPainter.shouldRepaint(oldPainter), isFalse);
    });
  });
}
