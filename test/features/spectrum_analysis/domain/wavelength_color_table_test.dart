import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/wavelength_color_table.dart';

void main() {
  group('wavelengthToRgb', () {
    test('violet end (~440nm) is predominantly blue', () {
      final rgb = wavelengthToRgb(440);
      expect(rgb[2], greaterThan(rgb[0]));
      expect(rgb[2], greaterThan(rgb[1]));
    });

    test('red end (~650nm) is predominantly red', () {
      final rgb = wavelengthToRgb(650);
      expect(rgb[0], greaterThan(rgb[1]));
      expect(rgb[0], greaterThan(rgb[2]));
    });

    test('green middle (~530nm) is predominantly green', () {
      final rgb = wavelengthToRgb(530);
      expect(rgb[1], greaterThan(rgb[0]));
      expect(rgb[1], greaterThan(rgb[2]));
    });

    test('every channel stays within 0-255', () {
      for (
        var nm = kMinVisibleWavelengthNm;
        nm <= kMaxVisibleWavelengthNm;
        nm += 10
      ) {
        final rgb = wavelengthToRgb(nm);
        for (final channel in rgb) {
          expect(channel, inInclusiveRange(0, 255));
        }
      }
    });
  });

  group('nearestWavelengthForRgb', () {
    test('finds an exact table entry for its own reference color', () {
      const targetNm = 550.0;
      final rgb = wavelengthToRgb(targetNm);

      final nm = nearestWavelengthForRgb(rgb[0], rgb[1], rgb[2]);

      expect(nm, targetNm);
    });

    test('result always stays within the visible range', () {
      final nm = nearestWavelengthForRgb(0, 0, 0);
      expect(
        nm,
        inInclusiveRange(kMinVisibleWavelengthNm, kMaxVisibleWavelengthNm),
      );
    });
  });
}
