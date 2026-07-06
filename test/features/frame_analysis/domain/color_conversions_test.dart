import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/color_conversions.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';

void main() {
  group('rgbToCmyk', () {
    test('white has zero ink on every channel', () {
      const white = RgbColor(r: 255, g: 255, b: 255);
      final cmyk = rgbToCmyk(white);
      expect(cmyk.c, 0);
      expect(cmyk.m, 0);
      expect(cmyk.y, 0);
      expect(cmyk.k, 0);
    });

    test('black is full key with zero c/m/y', () {
      const black = RgbColor(r: 0, g: 0, b: 0);
      final cmyk = rgbToCmyk(black);
      expect(cmyk.c, 0);
      expect(cmyk.m, 0);
      expect(cmyk.y, 0);
      expect(cmyk.k, 100);
    });

    test('pure red is full magenta+yellow with no key', () {
      const red = RgbColor(r: 255, g: 0, b: 0);
      final cmyk = rgbToCmyk(red);
      expect(cmyk.c, 0);
      expect(cmyk.m, 100);
      expect(cmyk.y, 100);
      expect(cmyk.k, 0);
    });
  });

  group('rgbToLab', () {
    test('white maps to L=100, a=0, b=0', () {
      const white = RgbColor(r: 255, g: 255, b: 255);
      final lab = rgbToLab(white);
      expect(lab.l, closeTo(100, 1));
      expect(lab.a, closeTo(0, 1));
      expect(lab.b, closeTo(0, 1));
    });

    test('black maps to L=0', () {
      const black = RgbColor(r: 0, g: 0, b: 0);
      final lab = rgbToLab(black);
      expect(lab.l, closeTo(0, 1));
      expect(lab.a, closeTo(0, 1));
      expect(lab.b, closeTo(0, 1));
    });

    test('pure sRGB red matches the well-known reference Lab value', () {
      // Standard reference: sRGB (255,0,0) -> Lab (53.24, 80.09, 67.20)
      // under a D65 white point.
      const red = RgbColor(r: 255, g: 0, b: 0);
      final lab = rgbToLab(red);
      expect(lab.l, closeTo(53, 1));
      expect(lab.a, closeTo(80, 1));
      expect(lab.b, closeTo(67, 1));
    });
  });

  group('RgbColor.hex', () {
    test('formats as lowercase, zero-padded #rrggbb', () {
      const color = RgbColor(r: 1, g: 10, b: 255);
      expect(color.hex, '#010aff');
    });
  });
}
