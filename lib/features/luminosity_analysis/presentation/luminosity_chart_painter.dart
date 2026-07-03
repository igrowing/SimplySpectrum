import 'package:flutter/material.dart';

import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';

/// Draws the live Luminosity sector chart: white polyline histogram on a
/// black background with a grey grid, and a static black-to-white
/// gradient reference bar underneath.
class LuminosityChartPainter extends CustomPainter {
  LuminosityChartPainter({required this.histogram});

  final LuminosityHistogram histogram;

  static const double _gradientBarHeight = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _gradientBarHeight;
    final plotRect = Rect.fromLTWH(0, 0, size.width, plotHeight);

    canvas.drawRect(plotRect, Paint()..color = Colors.black);
    _drawGrid(canvas, plotRect);
    _drawHistogram(canvas, plotRect);
    _drawGradientBar(canvas, size, plotHeight);
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade700
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

  void _drawHistogram(Canvas canvas, Rect rect) {
    final maxCount = histogram.bins.fold(0, (max, v) => v > max ? v : max);
    if (maxCount == 0) return;

    final path = Path();
    for (var i = 0; i < histogram.bins.length; i++) {
      final x = rect.left + rect.width * i / (histogram.bins.length - 1);
      final normalized = histogram.bins[i] / maxCount;
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
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawGradientBar(Canvas canvas, Size size, double top) {
    final rect = Rect.fromLTWH(0, top, size.width, _gradientBarHeight);
    final shader = const LinearGradient(
      colors: [Colors.black, Colors.white],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LuminosityChartPainter oldDelegate) {
    return oldDelegate.histogram != histogram;
  }
}
