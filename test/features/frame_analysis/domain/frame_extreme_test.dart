import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_extreme.dart';

void main() {
  group('NormalizedRect', () {
    const unitLeft = NormalizedRect(left: 0, top: 0, right: 0.4, bottom: 0.4);

    test('overlapFraction is 0 for disjoint rectangles', () {
      const far = NormalizedRect(left: 0.6, top: 0.6, right: 1, bottom: 1);
      expect(unitLeft.overlapFraction(far), 0);
    });

    test('overlapFraction is 1 when one rectangle contains the other', () {
      const inner = NormalizedRect(
        left: 0.1,
        top: 0.1,
        right: 0.2,
        bottom: 0.2,
      );
      expect(unitLeft.overlapFraction(inner), closeTo(1, 1e-9));
    });

    test('overlapFraction is symmetric and normalized by the smaller area', () {
      const other = NormalizedRect(
        left: 0.2,
        top: 0.2,
        right: 0.6,
        bottom: 0.6,
      );
      // Intersection is 0.2 x 0.2 = 0.04; smaller area is 0.16 -> 0.25.
      expect(unitLeft.overlapFraction(other), closeTo(0.25, 1e-9));
      expect(other.overlapFraction(unitLeft), closeTo(0.25, 1e-9));
    });

    test('inflated grows the rect on every edge', () {
      final grown = unitLeft.inflated(0.1);
      expect(grown.left, closeTo(-0.1, 1e-9));
      expect(grown.right, closeTo(0.5, 1e-9));
      expect(grown.bottom, closeTo(0.5, 1e-9));
    });

    test('lerp interpolates each edge', () {
      const a = NormalizedRect(left: 0, top: 0, right: 0, bottom: 0);
      const b = NormalizedRect(left: 1, top: 1, right: 1, bottom: 1);
      final mid = NormalizedRect.lerp(a, b, 0.25);
      expect(mid.left, closeTo(0.25, 1e-9));
      expect(mid.centerX, closeTo(0.25, 1e-9));
    });
  });
}
