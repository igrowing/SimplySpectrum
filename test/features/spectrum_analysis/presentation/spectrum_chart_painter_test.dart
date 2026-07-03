import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/spectrum_analysis/presentation/spectrum_chart_painter.dart';

void main() {
  group('nmToHz', () {
    test('400nm (violet end) is a higher frequency than 700nm (red end)', () {
      expect(nmToHz(400), greaterThan(nmToHz(700)));
    });

    test('matches c = f * lambda for a known value', () {
      // 500nm -> 3e8 / 500e-9 = 6e14 Hz.
      expect(nmToHz(500), closeTo(6e14, 1e12));
    });

    test('doubling wavelength halves frequency', () {
      final base = nmToHz(400);
      final doubled = nmToHz(800);

      expect(doubled, closeTo(base / 2, base / 2 * 0.01));
    });
  });
}
