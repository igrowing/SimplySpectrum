import 'package:flutter/material.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/wavelength_color_table.dart';

// ignore: prefer_int_literals - scientific notation is clearer here.
const double _kSpeedOfLightMPerS = 3e8;

double nmToHz(double nm) => _kSpeedOfLightMPerS / (nm * 1e-9);

/// Draws the live Spectrum sector chart: white polyline histogram on a
/// black background with a grey grid, a static 400-700nm color reference
/// bar with tick marks, and optional peak labels.
class SpectrumChartPainter extends CustomPainter {
  SpectrumChartPainter({
    required this.histogram,
    required this.unit,
    required this.showPeaks,
  });

  final SpectrumHistogram histogram;
  final SpectrumUnit unit;
  final bool showPeaks;

  static const double _colorBarHeight = 18;
  static const double _tickLabelHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _colorBarHeight - _tickLabelHeight;
    final plotRect = Rect.fromLTWH(0, 0, size.width, plotHeight);

    canvas.drawRect(plotRect, Paint()..color = Colors.black);
    _drawGrid(canvas, plotRect);
    _drawHistogram(canvas, plotRect);
    if (showPeaks) {
      _drawPeaks(canvas, plotRect);
    }
    _drawColorBar(canvas, size, plotHeight);
    _drawTicks(canvas, size, plotHeight);
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
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        gridPaint,
      );
    }
  }

  void _drawHistogram(Canvas canvas, Rect rect) {
    final maxCount = histogram.bins.fold(
      0,
      (max, v) => v > max ? v : max,
    );
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

  void _drawPeaks(Canvas canvas, Rect rect) {
    final maxCount = histogram.bins.fold(0, (max, v) => v > max ? v : max);
    if (maxCount == 0) return;

    final peaks = histogram.detectPeaks();
    for (final peak in peaks) {
      final binIndex = (peak.wavelengthNm - kMinVisibleWavelengthNm).round();
      final x = rect.left + rect.width * binIndex / (histogram.bins.length - 1);
      final normalized = peak.occurrences / maxCount;
      final y = rect.bottom - normalized * rect.height;

      canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = Colors.amber);

      final label = _labelFor(peak.wavelengthNm);
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.amber, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = (x - painter.width / 2).clamp(
        0.0,
        rect.width - painter.width,
      );
      painter.paint(
        canvas,
        Offset(labelX, (y - painter.height - 3).clamp(0, rect.height)),
      );
    }
  }

  String _labelFor(double nm) {
    if (unit == SpectrumUnit.wavelengthNm) {
      return '${nm.round()}nm';
    }
    final hz = nmToHz(nm);
    return '${(hz / 1e14).toStringAsFixed(2)}e14Hz';
  }

  void _drawColorBar(Canvas canvas, Size size, double top) {
    final barRect = Rect.fromLTWH(0, top, size.width, _colorBarHeight);
    const columns = 150;
    for (var i = 0; i < columns; i++) {
      final t = i / (columns - 1);
      final nm =
          kMinVisibleWavelengthNm +
          t * (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm);
      final rgb = wavelengthToRgb(nm);
      final x0 = barRect.left + barRect.width * i / columns;
      final x1 = barRect.left + barRect.width * (i + 1) / columns;
      canvas.drawRect(
        Rect.fromLTRB(x0, barRect.top, x1, barRect.bottom),
        Paint()..color = Color.fromARGB(255, rgb[0], rgb[1], rgb[2]),
      );
    }
  }

  void _drawTicks(Canvas canvas, Size size, double colorBarTop) {
    final y = colorBarTop + _colorBarHeight + 2;
    const stepNm = 100.0;
    var nm = kMinVisibleWavelengthNm;
    while (nm <= kMaxVisibleWavelengthNm + 0.01) {
      final t =
          (nm - kMinVisibleWavelengthNm) /
          (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm);
      final x = size.width * t;
      final label = unit == SpectrumUnit.wavelengthNm
          ? '${nm.round()}'
          : (nmToHz(nm) / 1e14).toStringAsFixed(1);

      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = (x - painter.width / 2).clamp(
        0.0,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(labelX, y));
      nm += stepNm;
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumChartPainter oldDelegate) {
    return oldDelegate.histogram != histogram ||
        oldDelegate.unit != unit ||
        oldDelegate.showPeaks != showPeaks;
  }
}
