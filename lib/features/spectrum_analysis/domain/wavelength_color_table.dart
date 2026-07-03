import 'dart:math' as math;

/// Lower/upper bounds of the human-visible spectrum this app models,
/// matching the fixed X axis of the Spectrum sector.
const double kMinVisibleWavelengthNm = 400;
const double kMaxVisibleWavelengthNm = 700;

/// Approximates the RGB color a human perceives for a monochromatic light
/// source at [wavelengthNm], using Dan Bruton's well-known 1996 formula
/// ("Computer Graphic Representation of the Visible Spectrum for Various
/// Wavelengths"). This is a perceptual approximation, not a colorimetric
/// (CIE) computation - it is good enough for driving the static spectrum
/// bar and for nearest-neighbor wavelength lookup, but is not a substitute
/// for calibrated spectrophotometry.
List<int> wavelengthToRgb(double wavelengthNm) {
  var r = 0.0;
  var g = 0.0;
  var b = 0.0;
  final nm = wavelengthNm;

  if (nm >= 380 && nm < 440) {
    r = -(nm - 440) / (440 - 380);
    g = 0;
    b = 1;
  } else if (nm >= 440 && nm < 490) {
    r = 0;
    g = (nm - 440) / (490 - 440);
    b = 1;
  } else if (nm >= 490 && nm < 510) {
    r = 0;
    g = 1;
    b = -(nm - 510) / (510 - 490);
  } else if (nm >= 510 && nm < 580) {
    r = (nm - 510) / (580 - 510);
    g = 1;
    b = 0;
  } else if (nm >= 580 && nm < 645) {
    r = 1;
    g = -(nm - 645) / (645 - 580);
    b = 0;
  } else if (nm >= 645 && nm <= 780) {
    r = 1;
    g = 0;
    b = 0;
  }

  double factor;
  if (nm >= 380 && nm < 420) {
    factor = 0.3 + 0.7 * (nm - 380) / (420 - 380);
  } else if (nm >= 420 && nm < 701) {
    factor = 1;
  } else if (nm >= 701 && nm <= 780) {
    factor = 0.3 + 0.7 * (780 - nm) / (780 - 701);
  } else {
    factor = 0;
  }

  const gamma = 0.8;
  int gammaAdjust(double component) {
    if (component <= 0) return 0;
    final value = 255 * math.pow(component * factor, gamma);
    return value.round().clamp(0, 255);
  }

  return [gammaAdjust(r), gammaAdjust(g), gammaAdjust(b)];
}

/// Precomputed 1nm-resolution lookup table across the visible range,
/// built once and reused by [nearestWavelengthForRgb].
final List<MapEntry<double, List<int>>> visibleSpectrumTable = List.generate(
  (kMaxVisibleWavelengthNm - kMinVisibleWavelengthNm).toInt() + 1,
  (i) {
    final nm = kMinVisibleWavelengthNm + i;
    return MapEntry(nm, wavelengthToRgb(nm));
  },
  growable: false,
);

/// Finds the visible wavelength (400-700nm) whose reference color is
/// closest (least Euclidean RGB distance) to the sampled pixel [r]/[g]/[b].
///
/// This is the core approximation used to turn an ordinary camera's RGB
/// pixels into a "detected wavelength" for the spectrum histogram. It is
/// intentionally documented as an approximation: a consumer phone camera
/// has no diffraction grating or monochromator, so this maps *perceived
/// color* to its closest monochromatic equivalent rather than measuring
/// true spectral power distribution.
double nearestWavelengthForRgb(int r, int g, int b) {
  var bestDistance = double.infinity;
  var bestNm = kMinVisibleWavelengthNm;

  for (final entry in visibleSpectrumTable) {
    final rgb = entry.value;
    final dr = rgb[0] - r;
    final dg = rgb[1] - g;
    final db = rgb[2] - b;
    final distance = (dr * dr + dg * dg + db * db).toDouble();
    if (distance < bestDistance) {
      bestDistance = distance;
      bestNm = entry.key;
    }
  }
  return bestNm;
}
