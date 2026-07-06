import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';

/// A CMYK color, each channel expressed as 0-100 (a percentage) and
/// rounded to the nearest integer for compact display.
class CmykColor extends Equatable {
  const CmykColor({
    required this.c,
    required this.m,
    required this.y,
    required this.k,
  });

  final int c;
  final int m;
  final int y;
  final int k;

  @override
  List<Object?> get props => [c, m, y, k];
}

/// A CIE L*a*b* color. [l] (lightness) is 0-100; [a] (green-red) and [b]
/// (blue-yellow) are typically roughly within -128..127. All 3 rounded
/// to the nearest integer for compact display.
///
/// This is a plain RGB -> Lab *conversion* (via linear-light sRGB and
/// CIE XYZ, D65 white point) describing a single color. Delta E 2000 is
/// a *difference* metric between two already-computed Lab colors, not a
/// color-space conversion - it has no role in producing one color's Lab
/// value, so it isn't used here. It would matter if/when the app needs
/// to compare two detected colors (e.g. "how close is this to a
/// reference swatch"), which isn't part of this feature.
class LabColor extends Equatable {
  const LabColor({required this.l, required this.a, required this.b});

  final int l;
  final int a;
  final int b;

  @override
  List<Object?> get props => [l, a, b];
}

/// Simple subtractive CMYK conversion from an additive sRGB color.
CmykColor rgbToCmyk(RgbColor rgb) {
  final rNorm = rgb.r / 255;
  final gNorm = rgb.g / 255;
  final bNorm = rgb.b / 255;

  final k = 1 - math.max(rNorm, math.max(gNorm, bNorm));
  if (k >= 1) {
    // Pure black: c/m/y are conventionally 0, not undefined, once k=100.
    return const CmykColor(c: 0, m: 0, y: 0, k: 100);
  }

  final c = (1 - rNorm - k) / (1 - k);
  final m = (1 - gNorm - k) / (1 - k);
  final y = (1 - bNorm - k) / (1 - k);

  return CmykColor(
    c: (c * 100).round(),
    m: (m * 100).round(),
    y: (y * 100).round(),
    k: (k * 100).round(),
  );
}

/// Converts sRGB -> CIE L*a*b* (D65 white point) via the standard
/// pipeline: sRGB -> linear-light RGB (gamma expansion) -> CIE XYZ ->
/// Lab.
LabColor rgbToLab(RgbColor rgb) {
  final rLin = _srgbChannelToLinear(rgb.r);
  final gLin = _srgbChannelToLinear(rgb.g);
  final bLin = _srgbChannelToLinear(rgb.b);

  // Linear sRGB -> XYZ, D65 white point (standard sRGB matrix).
  final x = rLin * 0.4124564 + gLin * 0.3575761 + bLin * 0.1804375;
  final y = rLin * 0.2126729 + gLin * 0.7151522 + bLin * 0.0721750;
  final z = rLin * 0.0193339 + gLin * 0.1191920 + bLin * 0.9503041;

  // D65 reference white (CIE 1931 2-degree observer).
  const xn = 0.95047;
  const yn = 1;
  const zn = 1.08883;

  final fx = _labF(x / xn);
  final fy = _labF(y / yn);
  final fz = _labF(z / zn);

  final l = 116 * fy - 16;
  final a = 500 * (fx - fy);
  final labB = 200 * (fy - fz);

  return LabColor(l: l.round(), a: a.round(), b: labB.round());
}

double _srgbChannelToLinear(int channel) {
  final normalized = channel / 255;
  return normalized <= 0.04045
      ? normalized / 12.92
      : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
}

const double _labDelta = 6 / 29;

double _labF(double t) {
  return t > _labDelta * _labDelta * _labDelta
      ? math.pow(t, 1 / 3).toDouble()
      : t / (3 * _labDelta * _labDelta) + 4 / 29;
}
