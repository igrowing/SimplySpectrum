import 'package:flutter/material.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analyzer.dart'
    show kColorEnhanceContrastBoost, kColorEnhanceSaturationBoost;

/// Rec.709 luma weights, used to build a standard "saturation matrix" -
/// the same construction as Android's `ColorMatrix.setSaturation` and
/// most 2D graphics saturation filters: boost/reduce the
/// perpendicular-to-luma component of each pixel while leaving its
/// perceived brightness unchanged.
const double _lumaR = 0.213;
const double _lumaG = 0.715;
const double _lumaB = 0.072;

/// A [ColorFilter] approximating the same saturation + contrast boost
/// `analyzeFrame` applies per-pixel when "Enhance colors" is on (see
/// `frame_analyzer.dart`'s `_enhance()`), so the live Camera sector
/// preview visually reflects the setting too, instead of only the
/// Spectrum/Luminosity charts changing while the preview looks
/// unaffected.
///
/// This is necessarily an approximation, not a pixel-identical match:
/// `_enhance()`'s saturation step scales each channel's distance from
/// *that pixel's own* max channel, which is a per-pixel-dependent
/// operation. `CameraPreview` renders a native platform texture, and a
/// [ColorFilter.matrix] can only apply one fixed linear transform
/// uniformly to every pixel - there's no per-pixel branching available.
/// A standard luma-preserving saturation matrix, combined with the same
/// contrast boost, gets visually very close for ordinary camera images,
/// which is what matters for a live preview (the histograms remain the
/// exact, pixel-accurate calculation).
ColorFilter buildEnhanceColorPreviewFilter() => ColorFilter.matrix(
  _saturationContrastMatrix(
    saturation: kColorEnhanceSaturationBoost,
    contrast: kColorEnhanceContrastBoost,
  ),
);

/// Builds a combined saturation + contrast 4x5 color matrix (the format
/// [ColorFilter.matrix] expects: row-major, operating on 0-255 values).
///
/// Saturation is applied first via the standard luma-preserving
/// construction, then contrast (a simple scale-around-128 operation)
/// is composed on top by scaling every RGB row and adding the
/// contrast's constant offset - since contrast has no cross-channel
/// mixing, this composition is exact, not an approximation in itself.
List<double> _saturationContrastMatrix({
  required double saturation,
  required double contrast,
}) {
  final sr = (1 - saturation) * _lumaR;
  final sg = (1 - saturation) * _lumaG;
  final sb = (1 - saturation) * _lumaB;

  // 128 is the neutral midpoint contrast pivots around, in the 0-255
  // scale ColorFilter.matrix operates in.
  final contrastOffset = 128 * (1 - contrast);

  return <double>[
    (sr + saturation) * contrast,
    sg * contrast,
    sb * contrast,
    0,
    contrastOffset,
    sr * contrast,
    (sg + saturation) * contrast,
    sb * contrast,
    0,
    contrastOffset,
    sr * contrast,
    sg * contrast,
    (sb + saturation) * contrast,
    0,
    contrastOffset,
    0,
    0,
    0,
    1,
    0,
  ];
}
