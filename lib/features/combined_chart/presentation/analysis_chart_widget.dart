import 'dart:async';

import 'package:flutter/material.dart';

import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/combined_chart_info_screen.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/combined_chart_painter.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';

import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

/// The combined live analysis chart: the spectrum (wavelength
/// occurrence) and luminosity (luma occurrence) histograms overlaid on
/// one dual-Y-axis plot - the spectrum line painted segment-by-segment
/// in its wavelength color (violet left, red right, 2px), the
/// luminosity line in a theme-contrasting color.
///
/// The chart is zoomable and pannable like a picture viewer: pinch to
/// zoom (1x-12x, both axes), drag to pan while zoomed, double-tap to
/// reset to the full chart. Grid lines and axis tick labels adapt to
/// the visible window, so zooming in reveals finer round-number ticks.
///
/// A small header shows both averages (wavelength in nm or THz,
/// luminosity in approx. lux), with a single info button at the
/// top-right corner opening one merged explanation of both lines.
class AnalysisChartWidget extends StatefulWidget {
  const AnalysisChartWidget({
    required this.spectrum,
    required this.luminosity,
    required this.unit,
    required this.showPeaks,
    required this.spectrumYAxisMax,
    required this.luminosityYAxisMax,
    super.key,
  });

  final SpectrumHistogram spectrum;
  final LuminosityHistogram luminosity;
  final SpectrumUnit unit;
  final bool showPeaks;
  final int spectrumYAxisMax;
  final int luminosityYAxisMax;

  static const double _minScale = 1;
  static const double _maxScale = 12;

  @override
  State<AnalysisChartWidget> createState() => AnalysisChartWidgetState();
}

class AnalysisChartWidgetState extends State<AnalysisChartWidget> {
  /// The current zoom/pan window (public for widget tests; the pan
  /// is top-based, matching [ChartViewport.top]).
  ChartViewport get viewport => _viewport;

  double _scale = 1;

  /// Pan position, in fractions of the full (unzoomed) chart content,
  /// measured from the content's left/top edges. Both stay 0 while
  /// unzoomed; while zoomed they're clamped to `[0, 1 - 1/scale]`.
  double _panX = 0;
  double _panY = 0;

  // Gesture bookkeeping: the content fraction that was under the
  // focal point when the gesture started, so the update can keep that
  // content point under the (moving) finger - which is what makes
  /// pinching feel anchored and dragging pan naturally.
  double _gestureStartScale = 1;
  double _gestureContentX = 0;
  double _gestureContentY = 0;

  ChartViewport get _viewport => ChartViewport(
    left: _panX,
    top: _panY,
    width: 1 / _scale,
    height: 1 / _scale,
  );

  void _resetZoom() {
    setState(() {
      _scale = 1;
      _panX = 0;
      _panY = 0;
    });
  }

  /// Plot rect inside the widget box, using the same margin constants
  /// the painter uses, so gesture focal points map exactly into
  /// content fractions.
  Rect _plotRect(BoxConstraints constraints) {
    return Rect.fromLTWH(
      CombinedChartPainter.leftAxisLabelWidth,
      0,
      constraints.maxWidth -
          CombinedChartPainter.leftAxisLabelWidth -
          CombinedChartPainter.rightAxisLabelWidth,
      constraints.maxHeight - CombinedChartPainter.bottomTicksHeight,
    );
  }

  void _onScaleStart(ScaleStartDetails details, BoxConstraints constraints) {
    _gestureStartScale = _scale;
    final plot = _plotRect(constraints);
    final local = details.localFocalPoint;
    _gestureContentX =
        _panX +
        (local.dx - plot.left).clamp(0.0, plot.width) / plot.width / _scale;
    _gestureContentY =
        _panY +
        (local.dy - plot.top).clamp(0.0, plot.height) / plot.height / _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, BoxConstraints constraints) {
    final plot = _plotRect(constraints);
    final local = details.localFocalPoint;
    final newScale = (_gestureStartScale * details.scale).clamp(
      AnalysisChartWidget._minScale,
      AnalysisChartWidget._maxScale,
    );

    // Keep the content point captured at gesture start under the
    // current focal point (this yields pan for free when the fingers
    // move without scaling), then clamp so the viewport never leaves
    // the chart content.
    final newPanX = _clampPan(
      _gestureContentX -
          (local.dx - plot.left).clamp(0.0, plot.width) / plot.width / newScale,
      newScale,
    );
    final newPanY = _clampPan(
      _gestureContentY -
          (local.dy - plot.top).clamp(0.0, plot.height) /
              plot.height /
              newScale,
      newScale,
    );

    setState(() {
      _scale = newScale;
      _panX = newPanX;
      _panY = newPanY;
    });
  }

  double _clampPan(double pan, double scale) {
    if (scale <= 1.0) return 0;
    return pan.clamp(0.0, 1 - 1 / scale);
  }

  String _spectrumAverageLabel() {
    final avgNm = widget.spectrum.weightedAverageNm;
    if (avgNm == null) return 'Avg: -';
    if (widget.unit == SpectrumUnit.wavelengthNm) {
      return 'Avg: ${avgNm.round()} nm';
    }
    final hz = nmToHz(avgNm);
    return 'Avg: ${(hz / 1e12).toStringAsFixed(2)} THz';
  }

  String _luminosityAverageLabel() {
    final avgLux = widget.luminosity.weightedAverageApproxLux;
    if (avgLux == null) return 'Avg: -';
    return 'Avg: ${avgLux.round()} lux';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // A theme-contrasting color for the luminosity line: it must read
    // against the current background in both themes, so derive it from
    // the scheme's on-surface color (near-white in dark theme,
    // near-black in light theme) rather than a fixed color.
    final luminosityLineColor = colorScheme.onSurface.withValues(
      alpha: 0.85,
    );

    return ColoredBox(
      color: colorScheme.surface,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 92, 4),
                child: Row(
                  children: [
                    Text(
                      _spectrumAverageLabel(),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _luminosityAverageLabel(),
                      style: TextStyle(
                        color: luminosityLineColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRect(
                  // The LayoutBuilder lives INSIDE the header-less chart
                  // area so its constraints - and thus `_plotRect` - match
                  // the GestureDetector's own local coordinates (its
                  // origin sits below the header), keeping the pinch/pan
                  // mapping exact.
                  child: LayoutBuilder(
                    builder: (context, chartConstraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (details) =>
                            _onScaleStart(details, chartConstraints),
                        onScaleUpdate: (details) =>
                            _onScaleUpdate(details, chartConstraints),
                        onDoubleTap: _resetZoom,
                        child: CustomPaint(
                          painter: CombinedChartPainter(
                            spectrum: widget.spectrum,
                            luminosity: widget.luminosity,
                            unit: widget.unit,
                            showPeaks: widget.showPeaks,
                            spectrumYAxisMax: widget.spectrumYAxisMax,
                            luminosityYAxisMax: widget.luminosityYAxisMax,
                            gridColor: colorScheme.onSurface.withValues(
                              alpha: 0.25,
                            ),
                            labelColor: colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            luminosityLineColor: luminosityLineColor,
                            viewport: _viewport,
                          ),
                          size: Size.infinite,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 6,
            right: 6,
            child: TranslucentIconButton(
              icon: Icons.info_outline,
              semanticLabel: 'Chart info',
              onPressed: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CombinedChartInfoScreen(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
