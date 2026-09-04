import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/pinch_zoom_hint_overlay.dart';

void main() {
  testWidgets('renders the hint and self-dismisses after 2 seconds', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinchZoomHintOverlay(onFinished: () => finished = true),
        ),
      ),
    );

    // The overlay is on screen with the pinch hint.
    expect(find.byType(PinchZoomHintOverlay), findsOneWidget);
    expect(find.text('Pinch to zoom'), findsOneWidget);

    // Not finished yet mid-animation.
    await tester.pump(const Duration(seconds: 1));
    expect(finished, isFalse);

    // Advance to the full display duration: the animation completes
    // and reports onFinished so the host removes it from the tree.
    await tester.pump(const Duration(seconds: 2));
    expect(finished, isTrue);
  });
}
