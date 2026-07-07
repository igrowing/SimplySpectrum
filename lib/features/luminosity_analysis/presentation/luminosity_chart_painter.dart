import 'package:flutter/material.dart';

import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';

/// Draws the live Luminosity sector chart: an orange polyline histogram
/// over a themed grid with Y-axis occurrence-count labels, and a static
/// black-to-white gradient reference bar underneath. The background
/// itself is left to the parent sector widget's ColoredBox to paint, so
/// it inverts with the theme along with the rest of the app's chrome.
///
/// The Y axis is normalized against [yAxisMax] rather than the current
/// frame's own peak bin, so the polyline's height is comparable between
/// updates; [yAxisMax] itself is expected to change only occasionally
/// (see `AnalysisViewModel.luminosityAxisMax`), not on every repaint.
class LuminosityChartPainter extends CustomPainter {
  LuminosityChartPainter({
    required this.histogram,
    required this.yAxisMax,
    required this.gridColor,
    required this.labelColor,
  });

  final LuminosityHistogram histogram;

  /// Occurrence count that maps to the top of the chart. A bin above
  /// this (possible between rescales, since data updates more often
  /// than the axis) simply clips at the top edge until the next
  /// rescale.
  final int yAxisMax;

  /// Theme-derived chrome colors (see the sector widget), so the grid
  /// and axis labels properly invert with the light/dark theme. The
  /// histogram polyline and the black-to-white gradient reference bar
  /// are substantive data, not chrome, so they keep their own fixed
  /// colors regardless of theme.
  final Color gridColor;
  final Color labelColor;

  static const double _gradientBarHeight = 14;
  static const double _yAxisLabelWidth = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _gradientBarHeight;
    final plotRect = Rect.fromLTWH(
      _yAxisLabelWidth,
      0,
      size.width - _yAxisLabelWidth,
      plotHeight,
    );

    _drawGrid(canvas, plotRect);
    _drawYAxisLabels(canvas, plotRect);
    _drawHistogram(canvas, plotRect);
    _drawGradientBar(canvas, plotRect, plotHeight);
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
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }
  }

  /// Draws occurrence-count labels to the left of the plot at the top
  /// (full [yAxisMax]), middle (half) and bottom (zero) grid lines. Each
  /// bin is a count of sampled pixels at that brightness level, so the
  /// unit is pixels ("px") - not lux. Lux would describe a brightness
  /// *value* (the X axis, shown via the gradient bar below), not "how
  /// many pixels were at that brightness".
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
      painter.paint(canvas, Offset(rect.left - _yAxisLabelWidth, y));
    }
  }

  void _drawHistogram(Canvas canvas, Rect rect) {
    if (yAxisMax == 0) return;

    final path = Path();
    for (var i = 0; i < histogram.bins.length; i++) {
      final x = rect.left + rect.width * i / (histogram.bins.length - 1);
      final normalized = (histogram.bins[i] / yAxisMax).clamp(0.0, 1.0);
      final y = rect.bottom - normalized * rect.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color.fromARGB(255, 255, 154, 23)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawGradientBar(Canvas canvas, Rect plotRect, double top) {
    final rect = Rect.fromLTWH(
      plotRect.left,
      top,
      plotRect.width,
      _gradientBarHeight,
    );
    final shader = const LinearGradient(
      colors: [Colors.black, Colors.white],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LuminosityChartPainter oldDelegate) {
    return oldDelegate.histogram != histogram ||
        oldDelegate.yAxisMax != yAxisMax ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}
