import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/combined_chart_painter.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

void main() {
  group('nmToHz', () {
    test('400nm (violet end) is a higher frequency than 700nm (red end)', () {
      expect(nmToHz(400), greaterThan(nmToHz(700)));
    });

    test('matches c = f * lambda for a known value', () {
      // 500nm -> 3e8 / 500e-9 = 6e14 Hz.
      expect(nmToHz(500), closeTo(6e14, 1e12));
    });
  });

  group('ChartViewport', () {
    test('equality is structural', () {
      const a = ChartViewport(left: 0.2, top: 0.1, width: 0.5, height: 0.5);
      const b = ChartViewport(left: 0.2, top: 0.1, width: 0.5, height: 0.5);
      const c = ChartViewport(left: 0.3, top: 0.1, width: 0.5, height: 0.5);

      expect(a, b);
      expect(a, isNot(c));
    });
  });

  CombinedChartPainter painter({
    SpectrumHistogram? spectrum,
    LuminosityHistogram? luminosity,
    SpectrumUnit unit = SpectrumUnit.wavelengthNm,
    bool showPeaks = false,
    int spectrumYAxisMax = 1,
    int luminosityYAxisMax = 1,
    ChartViewport viewport = const ChartViewport(),
  }) => CombinedChartPainter(
    spectrum: spectrum ?? SpectrumHistogram.empty(),
    luminosity: luminosity ?? LuminosityHistogram.empty(),
    unit: unit,
    showPeaks: showPeaks,
    spectrumYAxisMax: spectrumYAxisMax,
    luminosityYAxisMax: luminosityYAxisMax,
    gridColor: Colors.grey,
    labelColor: Colors.white,
    luminosityLineColor: Colors.white70,
    viewport: viewport,
  );

  group('CombinedChartPainter', () {
    test('paints empty histograms without throwing', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter().paint(canvas, const Size(400, 300)),
        returnsNormally,
      );
    });

    test('paints populated histograms without throwing', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final spectrumBins = List.filled(SpectrumHistogram.binCount, 0);
      spectrumBins[50] = 80; // ~450nm
      spectrumBins[180] = 120; // ~580nm
      final lumaBins = List.filled(kLumaBinCount, 0);
      lumaBins[128] = 90;

      expect(
        () => painter(
          spectrum: SpectrumHistogram(bins: spectrumBins),
          luminosity: LuminosityHistogram(bins: lumaBins),
          spectrumYAxisMax: 150,
          luminosityYAxisMax: 100,
          showPeaks: true,
        ).paint(canvas, const Size(400, 300)),
        returnsNormally,
      );
    });

    test('paints in frequency mode without throwing', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter(unit: SpectrumUnit.frequencyHz).paint(
          canvas,
          const Size(400, 300),
        ),
        returnsNormally,
      );
    });

    test('paints at a zoomed/panned viewport without throwing', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final spectrumBins = List.filled(SpectrumHistogram.binCount, 0);
      spectrumBins[100] = 50;
      final lumaBins = List.filled(kLumaBinCount, 0);
      lumaBins[10] = 20;

      expect(
        () => painter(
          spectrum: SpectrumHistogram(bins: spectrumBins),
          luminosity: LuminosityHistogram(bins: lumaBins),
          spectrumYAxisMax: 60,
          luminosityYAxisMax: 25,
          viewport: const ChartViewport(
            left: 0.25,
            top: 0.4,
            width: 0.25,
            height: 0.25,
          ),
        ).paint(canvas, const Size(400, 300)),
        returnsNormally,
      );
    });

    test(
      'screenYForBottomBasedFraction maps vertical pan like a picture '
      'viewer (regression: inverted pan direction)',
      () {
        const plotRect = Rect.fromLTWH(0, 0, 100, 100);

        // Unzoomed: content bottom (0) at the plot's bottom, content
        // top (1) at the plot's top.
        final full = painter();
        expect(full.screenYForBottomBasedFraction(0, plotRect), 100);
        expect(full.screenYForBottomBasedFraction(1, plotRect), 0);

        // Zoomed 2x and panned down so the top edge of the plot shows
        // the content's top (top-based viewport.top = 0): the visible
        // bottom-based band is [0.5, 1] - the chart's upper half.
        final pannedDown = painter(
          viewport: const ChartViewport(top: 0, width: 0.5, height: 0.5),
        );
        expect(pannedDown.contentBottomFraction, closeTo(0.5, 1e-9));
        expect(
          pannedDown.screenYForBottomBasedFraction(0.5, plotRect),
          100,
        ); // band bottom at plot bottom
        expect(pannedDown.screenYForBottomBasedFraction(1, plotRect), 0);

        // Panned up instead (top-based viewport.top = 0.5, still 2x):
        // the visible band is [0, 0.5] - the chart's lower half.
        final pannedUp = painter(
          viewport: const ChartViewport(top: 0.5, width: 0.5, height: 0.5),
        );
        expect(pannedUp.contentBottomFraction, 0);
        expect(pannedUp.screenYForBottomBasedFraction(0, plotRect), 100);
        expect(pannedUp.screenYForBottomBasedFraction(0.5, plotRect), 0);
      },
    );

    test('shouldRepaint reacts to viewport changes', () {
      final a = painter();
      final b = painter(
        viewport: const ChartViewport(left: 0.1, width: 0.9, height: 0.9),
      );

      expect(a.shouldRepaint(b), isTrue);
      expect(a.shouldRepaint(painter()), isFalse);
    });
  });
}
