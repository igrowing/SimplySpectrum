import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/core/charting/axis_scale.dart';

void main() {
  group('niceAxisMax', () {
    test('0 and 1 both floor to 1 so charts never divide by zero', () {
      expect(niceAxisMax(0), 1);
      expect(niceAxisMax(1), 1);
    });

    test('rounds up to the next nice step within a magnitude', () {
      expect(niceAxisMax(7), 10);
      expect(niceAxisMax(42), 50);
      expect(niceAxisMax(123), 200);
      expect(niceAxisMax(760), 1000);
    });

    test('an already-nice value maps to itself', () {
      expect(niceAxisMax(10), 10);
      expect(niceAxisMax(50), 50);
      expect(niceAxisMax(200), 200);
    });

    test('result is always >= the input', () {
      for (final value in [2, 3, 9, 11, 99, 101, 999, 1001, 4999]) {
        expect(niceAxisMax(value), greaterThanOrEqualTo(value));
      }
    });
  });
}
