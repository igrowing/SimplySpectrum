import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/analysis_chart_widget.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/combined_chart_painter.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: 400, height: 600, child: child),
  ),
);

AnalysisChartWidget _chart() => AnalysisChartWidget(
  spectrum: SpectrumHistogram.empty(),
  luminosity: LuminosityHistogram.empty(),
  unit: SpectrumUnit.wavelengthNm,
  showPeaks: false,
  spectrumYAxisMax: 1,
  luminosityYAxisMax: 1,
);

AnalysisChartWidgetState _state(WidgetTester tester) =>
    tester.state<AnalysisChartWidgetState>(find.byType(AnalysisChartWidget));

void main() {
  testWidgets('renders without throwing', (tester) async {
    await tester.pumpWidget(_wrap(_chart()));
    expect(find.byType(AnalysisChartWidget), findsOneWidget);
  });

  testWidgets(
    'pinch zooms in around the focal point, pan follows the finger '
    'direction, double-tap resets (regression: inverted vertical pan)',
    (tester) async {
      await tester.pumpWidget(_wrap(_chart()));

      final rect = tester.getRect(find.byType(AnalysisChartWidget));
      // Plot rect per the painter's shared margins: 34px side axes,
      // 28px bottom ticks.
      final plotCenter = Offset(
        rect.left +
            CombinedChartPainter.leftAxisLabelWidth +
            (rect.width -
                    CombinedChartPainter.leftAxisLabelWidth -
                    CombinedChartPainter.rightAxisLabelWidth) /
                2,
        (rect.height - CombinedChartPainter.bottomTicksHeight) / 2,
      );

      // Two-finger pinch: start 40px apart, end 120px apart -> 3x.
      final g1 = await tester.startGesture(plotCenter.translate(-20, 0));
      await tester.pump();
      final g2 = await tester.startGesture(plotCenter.translate(20, 0));
      // Advance past the double-tap timeout so the scale recognizer
      // wins the arena and captures its span baseline at pointer-down
      // (40px apart), the same way it resolves on a real device.
      await tester.pump(const Duration(milliseconds: 350));
      await g1.moveBy(const Offset(-40, 0));
      await tester.pump();
      await g2.moveBy(const Offset(40, 0));
      await tester.pump();
      await g1.up();
      await g2.up();
      await tester.pump();

      final afterPinch = _state(tester).viewport;
      // Fingers spread from 40px apart to 120px apart, so the chart
      // is zoomed in and the window is a strict sub-rectangle of the
      // full chart. (The exact factor depends on when the scale
      // recognizer wins the gesture arena, so only assert "zoomed".)
      expect(afterPinch.width, lessThan(0.9));
      expect(afterPinch.height, lessThan(0.9));
      expect(afterPinch.width, greaterThan(0.1));
      expect(afterPinch.height, greaterThan(0.1));
      // The viewport is anchored around the fingers - panned, but not
      // clamped against an edge.
      expect(afterPinch.left, greaterThan(0));
      expect(afterPinch.top, greaterThan(0));
      expect(afterPinch.left, lessThan(1 - afterPinch.width + 0.01));
      expect(afterPinch.top, lessThan(1 - afterPinch.height + 0.01));

      // Drag the chart UP: the content must follow the finger, i.e.
      // the viewport slides down the content (top-based `top` grows -
      // the plot's top edge starts showing content further down).
      // Move in small increments like a real finger: the gesture only
      // starts once the pointer passes touch slop, so one big jump
      // would be swallowed by the gesture-start snapshot.
      final drag = await tester.startGesture(plotCenter);
      for (var i = 0; i < 25; i++) {
        await drag.moveBy(const Offset(0, -4));
      }
      await tester.pump();
      await drag.up();
      await tester.pump();

      final afterDrag = _state(tester).viewport;
      expect(afterDrag.top, greaterThan(afterPinch.top + 0.03));
      // Horizontal pan untouched by a vertical drag.
      expect(afterDrag.left, closeTo(afterPinch.left, 0.001));

      // Drag the chart DOWN: content follows back down (`top` shrinks).
      final dragDown = await tester.startGesture(plotCenter);
      for (var i = 0; i < 50; i++) {
        await dragDown.moveBy(const Offset(0, 4));
      }
      await tester.pump();
      await dragDown.up();
      await tester.pump();

      final afterDragDown = _state(tester).viewport;
      expect(afterDragDown.top, lessThan(afterDrag.top - 0.03));

      // Double-tap resets to the full chart.
      await tester.tapAt(plotCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(plotCenter);
      await tester.pump();

      final reset = _state(tester).viewport;
      expect(reset.left, 0);
      expect(reset.top, 0);
      expect(reset.width, 1);
      expect(reset.height, 1);

      // Flush the double-tap recognizer's pending tap timer.
      await tester.pump(const Duration(milliseconds: 350));
    },
  );
}
