import 'package:flutter/material.dart';
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

/// A peak label placement candidate: its anchor point (the peak marker)
/// and the pre-laid-out text ready to paint.
class _PeakLabel {
  _PeakLabel({required this.x, required this.y, required this.painter});

  final double x;
  final double y;
  final TextPainter painter;
}

/// Draws the live Spectrum sector chart: a green polyline histogram
/// over a themed grid with Y-axis occurrence-count labels, a static
/// 400-700nm color reference bar with tick marks, and optional peak
/// labels. The background itself is left to the parent sector widget's
/// ColoredBox to paint, so it inverts with the theme along with the
/// rest of the app's chrome.
///
/// The X axis genuinely rescales with [unit]: in wavelength mode it is
/// linear in nm (as the histogram bins are stored); in frequency mode
/// every plotted position - grid, histogram, peaks, color bar and ticks
/// alike - is remapped so it is linear in Hz instead. Since frequency is
/// inversely proportional to wavelength, this is a genuinely different
/// (non-uniform, in bin-index terms) horizontal scale, not just a
/// relabeling of the same fixed tick positions.
///
/// The Y axis is normalized against [yAxisMax] rather than the current
/// frame's own peak bin, so the polyline's height is comparable between
/// updates; [yAxisMax] itself is expected to change only occasionally
/// (see `AnalysisViewModel.spectrumAxisMax`), not on every repaint.
class SpectrumChartPainter extends CustomPainter {
  SpectrumChartPainter({
    required this.histogram,
    required this.unit,
    required this.showPeaks,
    required this.yAxisMax,
    required this.gridColor,
    required this.labelColor,
  });

  final SpectrumHistogram histogram;
  final SpectrumUnit unit;
  final bool showPeaks;

  /// Occurrence count that maps to the top of the chart. A bin above
  /// this (possible between rescales, since data updates more often
  /// than the axis - see `AnalysisViewModel.kAxisRescaleInterval`)
  /// simply clips at the top edge until the next rescale.
  final int yAxisMax;

  /// Theme-derived chrome colors (see the sector widget), so the grid
  /// and axis/tick labels properly invert with the light/dark theme.
  /// The histogram polyline, peak markers, and the 400-700nm color
  /// reference bar are substantive data, not chrome, so they keep
  /// their own fixed colors regardless of theme.
  final Color gridColor;
  final Color labelColor;

  // Half its original height - the color reference bar only needs to
  // be a thin strip; a taller bar just ate into the chart's plot area
  // for no added information.
  static const double _colorBarHeight = 9;
  static const double _tickLabelHeight = 16;
  static const double _yAxisLabelWidth = 34;

  /// Minimum horizontal separation (px, in chart/screen space) between
  /// two displayed peak markers. Detected peaks closer together than
  /// this are treated as one cluster and only the single highest one
  /// in that cluster is shown (see [_drawPeaks]).
  static const double _minPeakSeparationPx = 37;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _colorBarHeight - _tickLabelHeight;
    final plotRect = Rect.fromLTWH(
      _yAxisLabelWidth,
      0,
      size.width - _yAxisLabelWidth,
      plotHeight,
    );

    _drawGrid(canvas, plotRect);
    _drawYAxisLabels(canvas, plotRect);
    _drawHistogram(canvas, plotRect);
    if (showPeaks) {
      _drawPeaks(canvas, plotRect);
    }
    _drawColorBar(canvas, plotRect, size, plotHeight);
    _drawTicks(canvas, plotRect, plotHeight);
  }

  /// Fraction (0-1, left-to-right) of the X axis a given wavelength maps
  /// to, under the currently selected [unit]. Wavelength mode is linear
  /// in nm; frequency mode is linear in Hz - so a peak near 700nm sits
  /// much closer to its neighbors in frequency mode than in wavelength
  /// mode, since Hz changes slowly with nm at the red end.
  double _xFraction(double nm) {
    if (unit == SpectrumUnit.wavelengthNm) {
      return (nm - kMinVisibleWavelengthNm) /
          (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm);
    }
    final hz = nmToHz(nm);
    return (_kMaxVisibleHz - hz) / (_kMaxVisibleHz - _kMinVisibleHz);
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const divisions = 4;
    for (var i = 1; i < divisions; i++) {
      final y = rect.top + rect.height * i / divisions;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }
    for (var i = 1; i < divisions; i++) {
      final x = rect.left + rect.width * i / divisions;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        gridPaint,
      );
    }
  }

  /// Draws occurrence-count labels to the left of the plot at the top
  /// (full [yAxisMax]), middle (half) and bottom (zero) grid lines. Each
  /// bin is a count of sampled pixels whose color matched that
  /// wavelength, so the unit is pixels ("px"), not a physical color
  /// quantity - there's no standard unit for "how many pixels looked
  /// this color".
  void _drawYAxisLabels(Canvas canvas, Rect rect) {
    final labelValues = [yAxisMax, yAxisMax ~/ 2, 0];
    final labelYs = [rect.top, rect.top + rect.height / 2, rect.bottom];

    for (var i = 0; i < labelValues.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: '${labelValues[i]}\npx',
          style: TextStyle(color: labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final y = (labelYs[i] - painter.height / 2).clamp(
        0.0,
        rect.height - painter.height,
      );
      painter.paint(
        canvas,
        Offset(rect.left - _yAxisLabelWidth, y),
      );
    }
  }

  void _drawHistogram(Canvas canvas, Rect rect) {
    if (yAxisMax == 0) return;

    final path = Path();
    var started = false;
    for (var i = 0; i < histogram.bins.length; i++) {
      final nm = kMinVisibleWavelengthNm + i;
      final x = rect.left + rect.width * _xFraction(nm);
      final normalized = (histogram.bins[i] / yAxisMax).clamp(0.0, 1.0);
      final y = rect.bottom - normalized * rect.height;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color.fromARGB(255, 30, 248, 67)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawPeaks(Canvas canvas, Rect rect) {
    if (yAxisMax == 0) return;

    // Ask the histogram for many more raw local-maxima candidates than
    // we intend to ever show; the pixel-distance suppression below (not
    // this count) is what actually decides how many survive.
    final peaks = histogram.detectPeaks(maxPeaks: 30);
    if (peaks.isEmpty) return;

    final peaksByXDesc = [
      for (final peak in peaks)
        (x: rect.left + rect.width * _xFraction(peak.wavelengthNm), peak: peak),
    ]..sort((a, b) => b.peak.occurrences.compareTo(a.peak.occurrences));

    // Non-max suppression in chart pixel space: walking from the
    // highest peak down, a peak is only kept if it isn't within
    // [_minPeakSeparationPx] of an already-kept (and therefore taller
    // or equal) peak. This collapses a tight cluster of local maxima -
    // e.g. sensor noise wobbling within one color band - down to a
    // single label for the tallest one, instead of showing every
    // little bump next to each other.
    final kept = <({double x, SpectrumPeak peak})>[];
    for (final candidate in peaksByXDesc) {
      final suppressed = kept.any(
        (existing) => (existing.x - candidate.x).abs() < _minPeakSeparationPx,
      );
      if (!suppressed) kept.add(candidate);
    }

    final candidates = <_PeakLabel>[
      for (final entry in kept)
        _PeakLabel(
          x: entry.x,
          y:
              rect.bottom -
              (entry.peak.occurrences / yAxisMax).clamp(0.0, 1.0) * rect.height,
          painter: TextPainter(
            text: TextSpan(
              text: _labelFor(entry.peak.wavelengthNm),
              style: const TextStyle(color: Colors.amber, fontSize: 9),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
        ),
    ];

    // Markers always sit exactly on the detected peak, regardless of
    // where its label ends up.
    for (final candidate in candidates) {
      canvas.drawCircle(
        Offset(candidate.x, candidate.y),
        2.5,
        Paint()..color = Colors.amber,
      );
    }

    // Place the topmost (highest-occurrence) peak's label first, at its
    // natural spot; each subsequent label - processed from topmost to
    // lowest - is nudged further above its marker until it clears the
    // minimum separation from every label already placed, so a cluster
    // of nearby peaks fans out into a readable vertical stack instead of
    // overlapping into unreadable text.
    final ordered = List<_PeakLabel>.from(candidates)
      ..sort((a, b) => a.y.compareTo(b.y));
    final placed = <Rect>[];

    for (final candidate in ordered) {
      final labelX = (candidate.x - candidate.painter.width / 2).clamp(
        rect.left,
        rect.right - candidate.painter.width,
      );
      var labelY = candidate.y - candidate.painter.height - 3;
      labelY = labelY.clamp(rect.top, rect.bottom - candidate.painter.height);

      placed.add(
        Rect.fromLTWH(
          labelX,
          labelY,
          candidate.painter.width,
          candidate.painter.height,
        ),
      );
      candidate.painter.paint(canvas, Offset(labelX, labelY));
    }
  }

  String _labelFor(double nm) {
    if (unit == SpectrumUnit.wavelengthNm) {
      return '${nm.round()}nm';
    }
    final hz = nmToHz(nm);
    return '${(hz / 1e12).toStringAsFixed(2)}THz';
  }

  void _drawColorBar(Canvas canvas, Rect plotRect, Size size, double top) {
    final barRect = Rect.fromLTWH(
      plotRect.left,
      top,
      plotRect.width,
      _colorBarHeight,
    );
    const columns = 150;
    for (var i = 0; i < columns; i++) {
      final t0 = i / columns;
      final t1 = (i + 1) / columns;
      final nm0 =
          kMinVisibleWavelengthNm +
          t0 * (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm);
      final nm1 =
          kMinVisibleWavelengthNm +
          t1 * (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm);
      final rgb = wavelengthToRgb(nm0);
      final x0 = barRect.left + barRect.width * _xFraction(nm0);
      final x1 = barRect.left + barRect.width * _xFraction(nm1);
      canvas.drawRect(
        Rect.fromLTRB(x0, barRect.top, x1, barRect.bottom),
        Paint()..color = Color.fromARGB(255, rgb[0], rgb[1], rgb[2]),
      );
    }
  }

  void _drawTicks(Canvas canvas, Rect plotRect, double colorBarTop) {
    final y = colorBarTop + _colorBarHeight + 2;

    final ticks = unit == SpectrumUnit.wavelengthNm
        ? _wavelengthTicks()
        : _frequencyTicks();

    for (final tick in ticks) {
      final x = plotRect.left + plotRect.width * tick.fraction;
      final painter = TextPainter(
        text: TextSpan(
          text: tick.label,
          style: TextStyle(color: labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = (x - painter.width / 2).clamp(
        plotRect.left,
        plotRect.right - painter.width,
      );
      painter.paint(canvas, Offset(labelX, y));
    }
  }

  /// Wavelength-mode ticks: fixed 100nm steps from 400 to 700nm, at the
  /// (nm-linear) X position each value naturally falls on.
  List<({double fraction, String label})> _wavelengthTicks() {
    final ticks = <({double fraction, String label})>[];
    const stepNm = 100.0;
    var nm = kMinVisibleWavelengthNm;
    while (nm <= kMaxVisibleWavelengthNm + 0.01) {
      ticks.add((fraction: _xFraction(nm), label: '${nm.round()}'));
      nm += stepNm;
    }
    return ticks;
  }

  /// Frequency-mode ticks: 5 values evenly spaced across the Hz range
  /// (~7.5e14 down to ~4.3e14), so - unlike relabeling the wavelength
  /// ticks in place - both the tick values *and* their spacing reflect a
  /// genuine linear-in-Hz axis.
  List<({double fraction, String label})> _frequencyTicks() {
    const divisions = 4;
    final ticks = <({double fraction, String label})>[];
    for (var i = 0; i <= divisions; i++) {
      final fraction = i / divisions;
      final hz = _kMaxVisibleHz - fraction * (_kMaxVisibleHz - _kMinVisibleHz);
      ticks.add((fraction: fraction, label: (hz / 1e14).toStringAsFixed(1)));
    }
    return ticks;
  }

  @override
  bool shouldRepaint(covariant SpectrumChartPainter oldDelegate) {
    return oldDelegate.histogram != histogram ||
        oldDelegate.unit != unit ||
        oldDelegate.showPeaks != showPeaks ||
        oldDelegate.yAxisMax != yAxisMax ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}
