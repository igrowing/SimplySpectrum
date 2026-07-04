import 'dart:math' as math;
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analysis_result.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/point_rotation.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/wavelength_color_table.dart';

/// Minimum color saturation (0-1, computed as (max-min)/max over RGB) a
/// sampled pixel must have to be counted in the spectrum histogram. Pixels
/// below this are treated as effectively achromatic (white/grey/black) and
/// don't correspond to a discernible monochromatic wavelength - counting
/// them would bias the average toward meaningless values.
const double _kMinChromaForSpectrum = 0.12;

/// Minimum luma a pixel must have before it's considered for chroma
/// analysis at all; very dark pixels have unreliable hue.
const int _kMinLumaForSpectrum = 8;

/// Every Nth pixel (in both axes) is sampled instead of processing every
/// pixel, keeping per-frame analysis fast enough to redraw live. A sampled
/// cell covers `sampleStep * sampleStep` source pixels, comfortably above
/// the "at least 20 sq. pixels" requirement for brightest/darkest point
/// detection when sampleStep >= 5.
const int kDefaultSampleStep = 8;

/// How much [_enhance] scales each channel's distance from its pixel's
/// own max channel when "Enhance colors" is on. Exposed (not private) so
/// the live Camera sector preview can build an approximating color
/// filter with the same boost - see `color_enhance_filter.dart`'s
/// `buildEnhanceColorPreviewFilter`.
const double kColorEnhanceSaturationBoost = 1.35;

/// How much [_enhance] scales each channel's distance from the neutral
/// midpoint (128) when "Enhance colors" is on. See
/// [kColorEnhanceSaturationBoost].
const double kColorEnhanceContrastBoost = 1.15;

/// Analyzes one [RawCameraFrame] (YUV420) into a [FrameAnalysisResult]:
/// a spectrum (wavelength) histogram, a luminosity histogram, and
/// optionally the brightest/darkest sampled points.
///
/// This is a pure function over plain byte buffers, so it has no Flutter
/// dependency and is directly unit-testable; the presentation layer runs
/// it off the UI thread (see `SpectrumLuminosityAnalyzerService`).
FrameAnalysisResult analyzeFrame(
  RawCameraFrame frame, {
  bool enhanceColors = false,
  bool locateBrightestPoint = false,
  bool locateDarkestPoint = false,
  int sampleStep = kDefaultSampleStep,
}) {
  if (frame.format != RawFrameFormat.yuv420 || frame.planes.length < 3) {
    return FrameAnalysisResult(
      spectrum: SpectrumHistogram.empty(),
      luminosity: LuminosityHistogram.empty(),
    );
  }

  final yPlane = frame.planes[0];
  final uPlane = frame.planes[1];
  final vPlane = frame.planes[2];

  final spectrumBins = List<int>.filled(SpectrumHistogram.binCount, 0);
  final luminosityBins = List<int>.filled(kLumaBinCount, 0);

  int? brightestLuma;
  var brightestX = 0;
  var brightestY = 0;
  int? darkestLuma;
  var darkestX = 0;
  var darkestY = 0;

  for (var y = 0; y < frame.height; y += sampleStep) {
    final uvY = y >> 1;
    for (var x = 0; x < frame.width; x += sampleStep) {
      final yIndex = y * yPlane.bytesPerRow + x * yPlane.pixelStride;
      if (yIndex >= yPlane.bytes.length) continue;
      final yValue = yPlane.bytes[yIndex];

      final uvX = x >> 1;
      final uIndex = uvY * uPlane.bytesPerRow + uvX * uPlane.pixelStride;
      final vIndex = uvY * vPlane.bytesPerRow + uvX * vPlane.pixelStride;
      if (uIndex >= uPlane.bytes.length || vIndex >= vPlane.bytes.length) {
        continue;
      }
      final uValue = uPlane.bytes[uIndex];
      final vValue = vPlane.bytes[vIndex];

      var rgb = _yuvToRgb(yValue, uValue, vValue);
      if (enhanceColors) {
        rgb = _enhance(rgb);
      }

      final luma = _lumaFromRgb(rgb[0], rgb[1], rgb[2]);
      luminosityBins[luma]++;

      if (locateBrightestPoint &&
          (brightestLuma == null || luma > brightestLuma)) {
        brightestLuma = luma;
        brightestX = x;
        brightestY = y;
      }
      if (locateDarkestPoint && (darkestLuma == null || luma < darkestLuma)) {
        darkestLuma = luma;
        darkestX = x;
        darkestY = y;
      }

      if (_chromaOf(rgb[0], rgb[1], rgb[2]) >= _kMinChromaForSpectrum &&
          luma >= _kMinLumaForSpectrum) {
        final nm = nearestWavelengthForRgb(rgb[0], rgb[1], rgb[2]);
        final binIndex = (nm - kMinVisibleWavelengthNm).round().clamp(
          0,
          SpectrumHistogram.binCount - 1,
        );
        spectrumBins[binIndex]++;
      }
    }
  }

  return FrameAnalysisResult(
    spectrum: SpectrumHistogram(bins: spectrumBins),
    luminosity: LuminosityHistogram(bins: luminosityBins),
    brightestPoint: brightestLuma == null
        ? null
        : _toDisplayPoint(
            rawX: brightestX / frame.width,
            rawY: brightestY / frame.height,
            luma: brightestLuma,
            frame: frame,
          ),
    darkestPoint: darkestLuma == null
        ? null
        : _toDisplayPoint(
            rawX: darkestX / frame.width,
            rawY: darkestY / frame.height,
            luma: darkestLuma,
            frame: frame,
          ),
  );
}

/// Converts a point expressed in raw sensor-buffer-normalized coordinates
/// into the space the displayed, auto-rotated `CameraPreview` uses, so
/// overlays land on the feature they're meant to mark rather than
/// drifting to wherever the unrotated raw buffer put it.
FramePoint _toDisplayPoint({
  required double rawX,
  required double rawY,
  required int luma,
  required RawCameraFrame frame,
}) {
  final display = rotatePointToDisplaySpace(
    x: rawX,
    y: rawY,
    sensorOrientationDegrees: frame.sensorOrientationDegrees,
    mirror: frame.isFrontFacing,
  );
  return FramePoint(normalizedX: display.x, normalizedY: display.y, luma: luma);
}

List<int> _yuvToRgb(int y, int u, int v) {
  final c = y;
  final d = u - 128;
  final e = v - 128;

  final r = (c + 1.402 * e).round().clamp(0, 255);
  final g = (c - 0.344136 * d - 0.714136 * e).round().clamp(0, 255);
  final b = (c + 1.772 * d).round().clamp(0, 255);
  return [r, g, b];
}

int _lumaFromRgb(int r, int g, int b) =>
    (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

double _chromaOf(int r, int g, int b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  if (maxC == 0) return 0;
  return (maxC - minC) / maxC;
}

/// Simple saturation + contrast boost applied before analysis when the
/// "Enhance colors" setting is on.
List<int> _enhance(List<int> rgb) {
  final maxC = math.max(rgb[0], math.max(rgb[1], rgb[2])).toDouble();
  if (maxC == 0) return rgb;

  return rgb
      .map((channel) {
        final saturated =
            maxC + (channel - maxC) * kColorEnhanceSaturationBoost;
        final contrasted = 128 + (saturated - 128) * kColorEnhanceContrastBoost;
        return contrasted.round().clamp(0, 255);
      })
      .toList(growable: false);
}
