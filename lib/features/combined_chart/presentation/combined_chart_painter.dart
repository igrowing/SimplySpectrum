import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/wavelength_color_table.dart';

// ignore: prefer_int_literals - scientific notation is clearer here.
const double _kSpeedOfLightMPerS = 3e8;

double nmToHz(double nm) => _kSpeedOfLightMPerS / (nm * 1e-9);

/// Frequency (Hz) at the short/violet end of the visible range - the
/// highest frequency in-range, reached at [kMinVisibleWavelengthNm].
final double _kMaxVisibleHz = nmToHz(kMinVisibleWavelengthNm);

/// Frequency (Hz) at the long/red end of the visible range - the lowest
/// frequency in-range, reached at [kMaxVisibleWavelengthNm].
final double _kMinVisibleHz = nmToHz(kMaxVisibleWavelengthNm);

/// The visible zoom window over the chart content, expressed in
/// fractions of the full (unzoomed) plot area: 0.0 = far left/top edge,
/// 1.0 = far right/bottom edge. `width`/`height` are `1 / scale`, so a
/// scale of 1 shows the whole chart (left = top = 0, width = height = 1).
///
/// Kept clamped by the widget (see `AnalysisChartWidget`) so the
/// painter can trust it: `left` is always within `[0, 1 - width]` and
/// `top` within `[0, 1 - height]`.
@immutable
class ChartViewport {
  const ChartViewport({
    this.left = 0,
    this.top = 0,
    this.width = 1,
    this.height = 1,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is ChartViewport &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// One tick to draw on an axis: its value-space position (already
/// converted to a 0-1 fraction of that axis's full domain) and its
/// pre-formatted label text.
typedef ChartTick = ({double fraction, String label});

/// Draws the combined live analysis chart: the wavelength-occurrence
/// histogram (spectrum) and the luma-occurrence histogram (luminosity)
/// overlaid on a single plot.
///
/// - The spectrum line is painted segment-by-segment in the perceived
///   color of each wavelength (violet at 400nm on the left through red
///   at 700nm on the right), 2px wide - the line itself carries the
///   color information, so no separate rainbow reference bar is drawn.
/// - The luminosity line is painted in a theme-contrasting color
///   (passed in by the widget as [luminosityLineColor]).
/// - Single Y axis: the left axis is the spectrum occurrence-count
///   scale (normalized against [spectrumYAxisMax]). Both axes would
///   read "pixels", which is redundant, so the luminosity line keeps
///   its own [luminosityYAxisMax] normalization for its shape but no
///   longer draws a right-side axis.
/// - The X axis is shared positionally: the spectrum spans it as
///   400-700nm (left to right, remapped linearly in Hz in frequency
///   mode), the luminosity spans it as luma 0-255. Tick labels for both
///   domains are drawn under the plot (nm/Hz row, luma row).
/// - [viewport] carries the pinch-zoom/pan state (picture-viewer
///   style): all data lines, grid lines and tick labels are generated
///   for the visible window only, so zooming in reveals finer detail
///   (finer ticks, more peak separation) rather than just magnifying.
class CombinedChartPainter extends CustomPainter {
  CombinedChartPainter({
    required this.spectrum,
    required this.luminosity,
    required this.unit,
    required this.showPeaks,
    required this.spectrumYAxisMax,
    required this.luminosityYAxisMax,
    required this.gridColor,
    required this.labelColor,
    required this.luminosityLineColor,
    this.viewport = const ChartViewport(),
  });

  final SpectrumHistogram spectrum;
  final LuminosityHistogram luminosity;
  final SpectrumUnit unit;
  final bool showPeaks;

  /// Occurrence count mapping to the top of the plot for the spectrum
  /// line (left Y axis). Bins above this clip at the top edge until the
  /// next axis rescale (see `AnalysisViewModel.spectrumAxisMax`).
  final int spectrumYAxisMax;

  /// Occurrence count mapping to the top of the plot for the
  /// luminosity line's normalization. No right axis is drawn for it -
  /// the left (spectrum) axis already reads "pixels", so a second
  /// pixel axis would be redundant; this only shapes the line.
  final int luminosityYAxisMax;

  /// Theme-derived chrome colors, so the grid and axis/tick labels
  /// properly invert with the light/dark theme. The spectrum polyline
  /// segments and peak markers are substantive data, not chrome, so
  /// they keep their own fixed colors regardless of theme.
  final Color gridColor;
  final Color labelColor;

  /// Theme-contrasting color for the luminosity line, chosen by the
  /// widget to stand out against the current background.
  final Color luminosityLineColor;

  /// The pinch-zoom/pan window over the chart content (see
  /// [ChartViewport]).
  final ChartViewport viewport;

  /// The bottom-based content fraction (0 = content bottom, 1 = content
  /// top) visible at the plot's bottom edge.
  ///
  /// [ChartViewport.top] is top-based (measured down from the content's
  /// top edge, matching how the gesture handler tracks the finger),
  /// while all data-line fractions here are bottom-based (0 = bottom of
  /// the chart, matching occurrence counts rising upward). This getter
  /// converts the viewport into the data fraction space: the visible
  /// bottom-based range is `[contentBottomFraction,
  /// contentBottomFraction + viewport.height]`.
  double get contentBottomFraction => 1 - viewport.top - viewport.height;

  /// Screen-space y for a bottom-based content [fraction] (0 = content
  /// bottom, 1 = content top) inside [plotRect], honoring the current
  /// [viewport]. Public so the pan-direction behavior is unit-testable.
  double screenYForBottomBasedFraction(double fraction, Rect plotRect) =>
      plotRect.bottom -
      (fraction - contentBottomFraction) / viewport.height * plotRect.height;

  // Margins, shared with `AnalysisChartWidget` (which uses them to map
  // gesture focal points into plot fractions).
  static const double leftAxisLabelWidth = 34;
  static const double rightAxisLabelWidth = 0;
  static const double bottomTicksHeight = 28;
  static const double spectrumLineWidth = 2;
  static const double luminosityLineWidth = 1.5;

  /// Minimum on-screen separation (px) between two displayed peak
  /// markers; closer detected peaks collapse to the tallest one.
  static const double _minPeakSeparationPx = 37;

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = Rect.fromLTWH(
      leftAxisLabelWidth,
      0,
      size.width - leftAxisLabelWidth - rightAxisLabelWidth,
      size.height - bottomTicksHeight,
    );

    // Screen-space mapping helpers: a "fraction" is 0-1 across (or up)
    // the full unzoomed plot; the viewport selects which slice of that
    // fraction space is currently on screen.
    double sx(double fraction) =>
        plotRect.left +
        (fraction - viewport.left) / viewport.width * plotRect.width;
    double sy(double fraction) =>
        screenYForBottomBasedFraction(fraction, plotRect);

    _drawGridAndAxes(canvas, plotRect, sx, sy);
    _drawLuminosityLine(canvas, plotRect, sx, sy);
    _drawSpectrumLine(canvas, plotRect, sx, sy);
    if (showPeaks) {
      _drawPeaks(canvas, plotRect, sx, sy);
    }
  }

  // --- Mapping from data to fraction space -------------------------------

  /// Fraction (0-1, left-to-right) of the X axis a given wavelength
  /// maps to, under the currently selected [unit]. Wavelength mode is
  /// linear in nm; frequency mode is linear in Hz.
  double spectrumXFraction(double nm) {
    if (unit == SpectrumUnit.wavelengthNm) {
      return (nm - kMinVisibleWavelengthNm) /
          (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm);
    }
    final hz = nmToHz(nm);
    return (_kMaxVisibleHz - hz) / (_kMaxVisibleHz - _kMinVisibleHz);
  }

  /// Fraction (0-1, left-to-right) of the X axis a given frequency
  /// maps to in frequency mode: linear in Hz, violet (high Hz) on the
  /// left.
  double hzXFraction(double hz) =>
      (_kMaxVisibleHz - hz) / (_kMaxVisibleHz - _kMinVisibleHz);

  /// Occurrence value as a 0-1 fraction of the spectrum Y axis (bottom
  /// = 0, top = [spectrumYAxisMax]).
  double spectrumYFraction(int occurrences) => spectrumYAxisMax == 0
      ? 0
      : (occurrences / spectrumYAxisMax).clamp(0.0, 1.0);

  /// Luma value (0-255) as a 0-1 fraction of the shared X axis.
  double lumaXFraction(double luma) => luma / 255;

  /// Occurrence value as a 0-1 fraction of the luminosity Y axis
  /// (bottom = 0, top = [luminosityYAxisMax]).
  double luminosityYFraction(int occurrences) => luminosityYAxisMax == 0
      ? 0
      : (occurrences / luminosityYAxisMax).clamp(0.0, 1.0);

  // --- Grid, axes and ticks -----------------------------------------------

  void _drawGridAndAxes(
    Canvas canvas,
    Rect plotRect,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Vertical grid + X tick labels for the spectrum domain.
    final spectrumTicks = _spectrumTicks();
    for (final tick in spectrumTicks) {
      final x = sx(tick.fraction);
      if (x < plotRect.left || x > plotRect.right) continue;
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        gridPaint,
      );
    }

    // Horizontal grid lines + Y tick labels for both Y axes, from the
    // visible value window of each scale.
    final spectrumYTicks = _valueTicks(
      contentBottomFraction * spectrumYAxisMax,
      (contentBottomFraction + viewport.height) * spectrumYAxisMax,
    );
    for (final tick in spectrumYTicks) {
      final fraction = tick.value / spectrumYAxisMax;
      final y = sy(fraction);
      if (y < plotRect.top - 1 || y > plotRect.bottom + 1) continue;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
    }

    _paintTickLabels(
      canvas,
      plotRect,
      spectrumYTicks.map(
        (t) => (
          fraction: t.value / spectrumYAxisMax,
          label: '${t.value.round()}',
        ),
      ),
      isYAxis: true,
    );

    // Bottom rows: spectrum domain ticks, then luma ticks.
    final lumaTicks = _lumaTicks();
    _paintTickLabels(canvas, plotRect, spectrumTicks, isYAxis: false);
    _paintTickLabels(
      canvas,
      plotRect,
      lumaTicks,
      isYAxis: false,
      row: 1,
      color: luminosityLineColor,
    );

    // "px" unit hint beside each Y axis.
    _paintUnitHints(canvas, plotRect);
  }

  void _paintUnitHints(Canvas canvas, Rect plotRect) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'px',
        style: TextStyle(color: labelColor, fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(4, plotRect.top - 2));
  }

  /// Generates ticks for the spectrum X domain (nm or Hz depending on
  /// [unit]) for the currently visible window.
  List<ChartTick> _spectrumTicks() {
    if (unit == SpectrumUnit.wavelengthNm) {
      final from = kMinVisibleWavelengthNm + viewport.left * 300;
      final to =
          kMinVisibleWavelengthNm + (viewport.left + viewport.width) * 300;
      final ticks = _valueTicks(from, to, targetCount: 6);
      return [
        for (final t in ticks)
          (
            fraction: spectrumXFraction(t.value),
            label: '${t.value.round()}',
          ),
      ];
    }
    final from =
        _kMaxVisibleHz - viewport.left * (_kMaxVisibleHz - _kMinVisibleHz);
    final to =
        _kMaxVisibleHz -
        (viewport.left + viewport.width) * (_kMaxVisibleHz - _kMinVisibleHz);
    final ticks = _valueTicks(from, to, targetCount: 6);
    return [
      for (final t in ticks)
        (
          fraction: hzXFraction(t.value),
          label: (t.value / 1e12).toStringAsFixed(1),
        ),
    ];
  }

  /// Generates ticks for the luma X domain (0-255) for the visible
  /// window, labeled in [luminosityLineColor]-tinted text to visually
  /// associate them with the luminosity line.
  List<ChartTick> _lumaTicks() {
    final from = viewport.left * 255;
    final to = (viewport.left + viewport.width) * 255;
    final ticks = _valueTicks(from, to, targetCount: 6);
    return [
      for (final t in ticks)
        (fraction: lumaXFraction(t.value), label: '${t.value.round()}'),
    ];
  }

  /// Nice-value ticks (steps of {1, 2, 5} x 10^n) covering [from, to],
  /// roughly [targetCount] of them. Used for every axis so zooming in
  /// naturally reveals finer-grained round-number ticks.
  List<({double value, double step})> _valueTicks(
    double from,
    double to, {
    int targetCount = 4,
  }) {
    if (to <= from) return const [];
    final rawStep = (to - from) / targetCount;
    final magnitude = _pow10(rawStep);
    double step;
    if (rawStep <= 1 * magnitude) {
      step = 1 * magnitude;
    } else if (rawStep <= 2 * magnitude) {
      step = 2 * magnitude;
    } else if (rawStep <= 5 * magnitude) {
      step = 5 * magnitude;
    } else {
      step = 10 * magnitude;
    }
    final first = (from / step).ceil() * step;
    final ticks = <({double value, double step})>[];
    for (var v = first; v <= to + step * 0.001; v += step) {
      ticks.add((value: v, step: step));
    }
    return ticks;
  }

  double _pow10(double v) =>
      math.pow(10, (math.log(v) / math.ln10).floorToDouble()).toDouble();

  void _paintTickLabels(
    Canvas canvas,
    Rect plotRect,
    Iterable<ChartTick> ticks, {
    required bool isYAxis,
    int row = 0,
    Color? color,
  }) {
    for (final tick in ticks) {
      final painter = TextPainter(
        text: TextSpan(
          text: tick.label,
          style: TextStyle(color: color ?? labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      Offset offset;
      if (isYAxis) {
        final y = _screenYForFraction(plotRect, tick.fraction);
        if (y < plotRect.top - 1 || y > plotRect.bottom + 1) continue;
        offset = Offset(
          plotRect.left - painter.width - 6,
          (y - painter.height / 2).clamp(
            plotRect.top,
            plotRect.bottom - painter.height,
          ),
        );
      } else {
        final x = _screenXForFraction(plotRect, tick.fraction);
        if (x < plotRect.left || x > plotRect.right) continue;
        final rowY = plotRect.bottom + 3 + row * 13;
        offset = Offset(
          (x - painter.width / 2).clamp(
            plotRect.left,
            plotRect.right - painter.width,
          ),
          rowY,
        );
      }
      painter.paint(canvas, offset);
    }
  }

  double _screenXForFraction(Rect plotRect, double fraction) =>
      plotRect.left +
      (fraction - viewport.left) / viewport.width * plotRect.width;

  double _screenYForFraction(Rect plotRect, double fraction) =>
      screenYForBottomBasedFraction(fraction, plotRect);

  // --- Data lines ----------------------------------------------------------

  void _drawLuminosityLine(
    Canvas canvas,
    Rect plotRect,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    if (luminosityYAxisMax == 0) return;
    final paint = Paint()
      ..color = luminosityLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = luminosityLineWidth;

    var started = false;
    double? prevX;
    double? prevY;
    for (var i = 0; i < luminosity.bins.length; i++) {
      final x = sx(lumaXFraction(i.toDouble()));
      final y = sy(luminosityYFraction(luminosity.bins[i]));
      if (!started) {
        prevX = x;
        prevY = y;
        started = true;
        continue;
      }
      // Skip segments entirely off-screen horizontally; vertical values
      // clamp naturally since sy() maps them outside the plot - the
      // widget's canvas clip keeps the drawing tidy.
      final segmentOffScreen =
          (x < plotRect.left && prevX! < plotRect.left) ||
          (x > plotRect.right && prevX! > plotRect.right);
      if (!segmentOffScreen) {
        canvas.drawLine(Offset(prevX!, prevY!), Offset(x, y), paint);
      }
      prevX = x;
      prevY = y;
    }
  }

  void _drawSpectrumLine(
    Canvas canvas,
    Rect plotRect,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    if (spectrumYAxisMax == 0) return;

    var prevX = sx(spectrumXFraction(kMinVisibleWavelengthNm));
    var prevY = sy(spectrumYFraction(spectrum.bins.first));
    for (var i = 1; i < spectrum.bins.length; i++) {
      final nm = kMinVisibleWavelengthNm + i;
      final x = sx(spectrumXFraction(nm));
      final y = sy(spectrumYFraction(spectrum.bins[i]));

      final segmentVisible =
          !(x < plotRect.left && prevX < plotRect.left) &&
          !(x > plotRect.right && prevX > plotRect.right);
      if (segmentVisible) {
        final rgb = wavelengthToRgb(nm - 0.5);
        canvas.drawLine(
          Offset(prevX, prevY),
          Offset(x, y),
          Paint()
            ..color = Color.fromARGB(255, rgb[0], rgb[1], rgb[2])
            ..style = PaintingStyle.stroke
            ..strokeWidth = spectrumLineWidth,
        );
      }
      prevX = x;
      prevY = y;
    }
  }

  // --- Peaks ----------------------------------------------------------------

  void _drawPeaks(
    Canvas canvas,
    Rect plotRect,
    double Function(double) sx,
    double Function(double) sy,
  ) {
    if (spectrumYAxisMax == 0) return;

    final peaks = spectrum.detectPeaks(maxPeaks: 30);
    if (peaks.isEmpty) return;

    final peaksByXDesc = [
      for (final peak in peaks)
        (
          x: sx(spectrumXFraction(peak.wavelengthNm)),
          y: sy(spectrumYFraction(peak.occurrences)),
          peak: peak,
        ),
    ]..sort((a, b) => b.peak.occurrences.compareTo(a.peak.occurrences));

    // Non-max suppression in chart pixel space: a peak is only kept if
    // it isn't within [_minPeakSeparationPx] of an already-kept (and
    // therefore taller or equal) peak.
    final kept = <({double x, double y, SpectrumPeak peak})>[];
    for (final candidate in peaksByXDesc) {
      final suppressed = kept.any(
        (existing) => (existing.x - candidate.x).abs() < _minPeakSeparationPx,
      );
      if (!suppressed) kept.add(candidate);
    }

    for (final peak in kept) {
      if (peak.x < plotRect.left - 4 ||
          peak.x > plotRect.right + 4 ||
          peak.y < plotRect.top - 4 ||
          peak.y > plotRect.bottom + 4) {
        continue;
      }
      canvas.drawCircle(
        Offset(peak.x, peak.y),
        2.5,
        Paint()..color = Colors.amber,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: _labelFor(peak.peak.wavelengthNm),
          style: const TextStyle(color: Colors.amber, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = (peak.x - painter.width / 2).clamp(
        plotRect.left,
        plotRect.right - painter.width,
      );
      var labelY = peak.y - painter.height - 3;
      labelY = labelY.clamp(
        plotRect.top,
        plotRect.bottom - painter.height,
      );
      painter.paint(canvas, Offset(labelX, labelY));
    }
  }

  String _labelFor(double nm) {
    if (unit == SpectrumUnit.wavelengthNm) {
      return '${nm.round()}nm';
    }
    final hz = nmToHz(nm);
    return '${(hz / 1e12).toStringAsFixed(2)}THz';
  }

  @override
  bool shouldRepaint(covariant CombinedChartPainter oldDelegate) {
    return oldDelegate.spectrum != spectrum ||
        oldDelegate.luminosity != luminosity ||
        oldDelegate.unit != unit ||
        oldDelegate.showPeaks != showPeaks ||
        oldDelegate.spectrumYAxisMax != spectrumYAxisMax ||
        oldDelegate.luminosityYAxisMax != luminosityYAxisMax ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.luminosityLineColor != luminosityLineColor ||
        oldDelegate.viewport != viewport;
  }
}
