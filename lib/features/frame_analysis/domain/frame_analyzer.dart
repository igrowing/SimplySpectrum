import 'dart:math' as math;
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_analysis_result.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_extreme.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/point_rotation.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';
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
/// analysis at all. Very dark pixels have unreliable hue dominated by
/// sensor noise, and tend to map to the violet end of the spectrum
/// (the darkest reference colors in the wavelength table). 40 filters
/// out dark noise while preserving real color signal — a genuinely
/// colored object under reasonable lighting produces luma well above 40.
const int _kMinLumaForSpectrum = 40;

/// Every Nth pixel (in both axes) is sampled for the spectrum/luminosity
/// histograms and average color instead of processing every pixel,
/// keeping per-frame analysis fast enough to redraw live. (Brightest/
/// darkest region detection does NOT use this grid - see
/// [_locateExtremes].)
const int kDefaultSampleStep = 8;

/// Target column count of the coarse luma grid used for brightest/darkest
/// *region* detection. The Y plane is box-filtered down to roughly this
/// many columns (and a proportional number of rows); each grid cell is
/// the mean luma over every source pixel it covers - on a real >=480p
/// frame one cell already spans far more than the "at least 20 sq.
/// pixels" the feature requires, so noise, hot pixels and specular
/// sparkle are averaged out before any argmax/argmin is taken.
const int kExtremesGridCols = 40;

/// Fraction of the frame trimmed off *each* edge before brightest/darkest
/// region detection. Two reasons:
///
///  * The raw Y plane routinely has a near-black band along one or more
///    edges - row-alignment padding rows the plugin still counts in
///    `height`, un-cropped ISP "optical black" rows, lens-mount
///    vignetting - which would otherwise register as a large very dark
///    region and capture the darkest marker (and drag the mask threshold
///    down so real dark features fall outside it).
///  * The live preview is `BoxFit.cover`, so a strip on two edges of the
///    frame is cropped off screen entirely. A spot detected there would
///    get a marker that's clipped or invisible.
///
/// The genuine darkest/brightest spot a user cares about is well inside
/// the frame, so trimming a 10% border is pure upside.
const double _kExtremesEdgeInset = 0.10;

/// A grid cell joins the bright (or dark) mask when its mean luma is
/// within `max(_kExtremesMinMargin, range * _kExtremesMarginFrac)` of the
/// most extreme cell, where `range` is max-minus-min cell mean over the
/// whole grid.
const double _kExtremesMarginFrac = 0.10;
const double _kExtremesMinMargin = 6;

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

  var sampleCount = 0;
  var rSum = 0;
  var gSum = 0;
  var bSum = 0;

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

      sampleCount++;
      rSum += rgb[0];
      gSum += rgb[1];
      bSum += rgb[2];

      final luma = _lumaFromRgb(rgb[0], rgb[1], rgb[2]);
      luminosityBins[luma]++;

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

  // Cap the first 4 wavelength bins (400-403nm, the violet end where
  // dark-pixel noise piles up) to the max of all remaining bins, so that
  // violet-end noise can never dwarf real signal on the chart. Real violet
  // light still shows up — it just can't exceed the tallest real peak.
  if (spectrumBins.length > 4) {
    final realSignalMax = spectrumBins
        .sublist(4)
        .fold(0, (max, v) => v > max ? v : max);
    for (var i = 0; i < 4; i++) {
      if (spectrumBins[i] > realSignalMax) {
        spectrumBins[i] = realSignalMax;
      }
    }
  }

  final extremes = _locateExtremes(
    yPlane,
    frame: frame,
    locateBrightest: locateBrightestPoint,
    locateDarkest: locateDarkestPoint,
  );

  return FrameAnalysisResult(
    spectrum: SpectrumHistogram(bins: spectrumBins),
    luminosity: LuminosityHistogram(bins: luminosityBins),
    averageColor: sampleCount == 0
        ? null
        : RgbColor(
            r: (rSum / sampleCount).round().clamp(0, 255),
            g: (gSum / sampleCount).round().clamp(0, 255),
            b: (bSum / sampleCount).round().clamp(0, 255),
          ),
    brightestRegion: extremes?.brightest,
    darkestRegion: extremes?.darkest,
  );
}

// ===========================================================================
// Brightest / darkest region detection (A + D + E, on the raw Y plane).
//
//  A  Box-filter the Y plane (minus a _kExtremesEdgeInset border, which
//     is usually padding / optical-black / vignetting rather than scene)
//     down to a coarse grid of per-cell mean luma, so every candidate is
//     an *area* mean rather than one pixel - kills hot pixels, sensor
//     noise and specular sparkle before any argmax.
//  D  Threshold near the most extreme cell, label 4-connected components,
//     and (past a minimum-size gate that rejects lone noise cells) pick
//     the component that contains the most extreme cell.
//  E  Position the marker at the luma-weighted centroid of the most
//     extreme cells *within that one component* - never a global centroid,
//     which would land between two separate regions.
//
//  F  Reads the Y plane directly (Y already *is* luma) instead of the
//     YUV->RGB->luma round trip the histogram loop uses.
//  I  Independent of the "Enhance colors" setting - detection always runs
//     on the unmodified sensor luma.
// ===========================================================================

/// One box-filtered luma grid: `cols * rows` cells, each holding the mean
/// luma over the source pixels it covers (or a negative sentinel if the
/// cell somehow received no samples).
///
/// The grid covers only the analysed region of interest - the frame with
/// [_kExtremesEdgeInset] trimmed off each edge - so [roiLeft]..[roiBottom]
/// (normalized 0..1 in the *full* frame) are needed to map a cell back to
/// full-frame coordinates.
class _LumaGrid {
  _LumaGrid(
    this.cols,
    this.rows, {
    required this.roiLeft,
    required this.roiTop,
    required this.roiRight,
    required this.roiBottom,
  }) : mean = List<double>.filled(cols * rows, 0);

  final int cols;
  final int rows;
  final List<double> mean;
  final double roiLeft;
  final double roiTop;
  final double roiRight;
  final double roiBottom;

  double get roiWidth => roiRight - roiLeft;
  double get roiHeight => roiBottom - roiTop;
}

({FrameExtreme? brightest, FrameExtreme? darkest})? _locateExtremes(
  RawFramePlane yPlane, {
  required RawCameraFrame frame,
  required bool locateBrightest,
  required bool locateDarkest,
}) {
  if (!locateBrightest && !locateDarkest) return null;
  final grid = _buildLumaGrid(yPlane, frame.width, frame.height);
  if (grid == null) return null;
  return (
    brightest: locateBrightest
        ? _detectExtreme(grid, frame: frame, bright: true)
        : null,
    darkest: locateDarkest
        ? _detectExtreme(grid, frame: frame, bright: false)
        : null,
  );
}

/// Step A: reduce the analysed region (the frame minus a
/// [_kExtremesEdgeInset] border on every side) to a `~kExtremesGridCols`-
/// wide grid of per-cell mean luma, reading *every* source pixel in that
/// region exactly once.
_LumaGrid? _buildLumaGrid(RawFramePlane yPlane, int width, int height) {
  if (width < 2 || height < 2) return null;

  // Region of interest: trim the border unless the frame is too small for
  // the trim to leave a usable area (keeps tiny synthetic test frames
  // working).
  var insetX = (width * _kExtremesEdgeInset).round();
  var insetY = (height * _kExtremesEdgeInset).round();
  if (width - 2 * insetX < 8 || height - 2 * insetY < 8) {
    insetX = 0;
    insetY = 0;
  }
  final roiX0 = insetX;
  final roiY0 = insetY;
  final roiWidth = width - 2 * insetX;
  final roiHeight = height - 2 * insetY;

  final cols = roiWidth < kExtremesGridCols ? roiWidth : kExtremesGridCols;
  final rows = roiHeight < kExtremesGridCols
      ? roiHeight
      : math.max(
          1,
          math.min(roiHeight, (kExtremesGridCols * roiHeight) ~/ roiWidth),
        );

  final cellCount = cols * rows;
  final sums = List<int>.filled(cellCount, 0);
  final counts = List<int>.filled(cellCount, 0);

  // Per-column cell index (indexed by offset within the ROI), hoisted out
  // of the inner loop to avoid a divide per source pixel.
  final colOfX = List<int>.generate(roiWidth, (i) => (i * cols) ~/ roiWidth);

  final bytes = yPlane.bytes;
  final bytesPerRow = yPlane.bytesPerRow;
  final pixelStride = yPlane.pixelStride;
  for (var y = roiY0; y < roiY0 + roiHeight; y++) {
    final rowBase = (((y - roiY0) * rows) ~/ roiHeight) * cols;
    final lineBase = y * bytesPerRow;
    for (var x = roiX0; x < roiX0 + roiWidth; x++) {
      final index = lineBase + x * pixelStride;
      if (index >= bytes.length) continue;
      final cell = rowBase + colOfX[x - roiX0];
      sums[cell] += bytes[index];
      counts[cell]++;
    }
  }

  final grid = _LumaGrid(
    cols,
    rows,
    roiLeft: roiX0 / width,
    roiTop: roiY0 / height,
    roiRight: (roiX0 + roiWidth) / width,
    roiBottom: (roiY0 + roiHeight) / height,
  );
  for (var i = 0; i < cellCount; i++) {
    grid.mean[i] = counts[i] == 0 ? -1.0 : sums[i] / counts[i];
  }
  return grid;
}

/// Steps D + E: turn the coarse grid into a single bright (or dark)
/// region and its marker point.
FrameExtreme? _detectExtreme(
  _LumaGrid grid, {
  required RawCameraFrame frame,
  required bool bright,
}) {
  final cols = grid.cols;
  final rows = grid.rows;
  final mean = grid.mean;
  final cellCount = cols * rows;

  var extreme = bright ? -1.0 : 256.0;
  var lo = 256.0;
  var hi = -1.0;
  for (var i = 0; i < cellCount; i++) {
    final m = mean[i];
    if (m < 0) continue;
    if (m < lo) lo = m;
    if (m > hi) hi = m;
    if (bright ? m > extreme : m < extreme) extreme = m;
  }
  if (hi < 0) return null; // No valid cells at all.

  final margin = math.max(
    _kExtremesMinMargin,
    (hi - lo) * _kExtremesMarginFrac,
  );
  final threshold = bright ? extreme - margin : extreme + margin;
  bool inMask(int cell) {
    final m = mean[cell];
    return m >= 0 && (bright ? m >= threshold : m <= threshold);
  }

  // Step D: 4-connected components over the masked cells.
  final labels = List<int>.filled(cellCount, -1);
  final components = <List<int>>[];
  final stack = <int>[];
  for (var start = 0; start < cellCount; start++) {
    if (labels[start] != -1 || !inMask(start)) continue;
    final label = components.length;
    final component = <int>[];
    labels[start] = label;
    stack.add(start);
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      component.add(cell);
      final cx = cell % cols;
      final cy = cell ~/ cols;
      if (cx > 0) _visit(cell - 1, label, labels, stack, inMask);
      if (cx < cols - 1) _visit(cell + 1, label, labels, stack, inMask);
      if (cy > 0) _visit(cell - cols, label, labels, stack, inMask);
      if (cy < rows - 1) _visit(cell + cols, label, labels, stack, inMask);
    }
    components.add(component);
  }
  if (components.isEmpty) return null;

  // Gate out lone noise cells; fall back to all components only if the
  // gate would leave nothing.
  final minRegionCells = math.max(2, cellCount ~/ 400);
  var pool = components.where((c) => c.length >= minRegionCells).toList();
  if (pool.isEmpty) pool = components;

  // Step D: among the survivors, the region that *contains* the most
  // extreme cell wins - i.e. the darkest/brightest spot is wherever the
  // single darkest/brightest area is, as long as that area is part of a
  // large-enough region. Selecting by region *mean* instead would let a
  // small, uniformly-dim patch (e.g. a shadowed shelf) beat a big region
  // that has a genuinely black core but is broken up by brighter clutter
  // (e.g. the deep shadow under a desk) - which testers reported as
  // "misdetected".
  var best = pool.first;
  var bestExtremeCell = _regionExtremeCell(best, mean, bright: bright);
  for (final component in pool.skip(1)) {
    final e = _regionExtremeCell(component, mean, bright: bright);
    if (bright ? e > bestExtremeCell : e < bestExtremeCell) {
      best = component;
      bestExtremeCell = e;
    }
  }
  final bestMean = _regionMean(best, mean);

  // Step E: luma-weighted centroid over the whole region. Weighting each
  // cell by the square of its margin past the mask threshold pulls the
  // marker toward the region's hot/cold core when there's a gradient,
  // while a uniform region reduces to its geometric centre (rather than
  // an arbitrary subset of equally-extreme cells).
  var weightSum = 0.0;
  var weightedX = 0.0;
  var weightedY = 0.0;
  var coreLuma = bright ? 0.0 : 255.0;
  for (final cell in best) {
    final m = mean[cell];
    var margin = bright ? m - threshold : threshold - m;
    if (margin < 1) margin = 1;
    final weight = margin * margin;
    weightSum += weight;
    weightedX += weight * (cell % cols + 0.5);
    weightedY += weight * (cell ~/ cols + 0.5);
    if (bright ? m > coreLuma : m < coreLuma) coreLuma = m;
  }
  // Grid coordinates are normalized within the ROI; map them back to the
  // full frame before rotation.
  double toFrameX(double roiNormX) => grid.roiLeft + grid.roiWidth * roiNormX;
  double toFrameY(double roiNormY) => grid.roiTop + grid.roiHeight * roiNormY;

  final rawCentroidX = toFrameX(weightedX / weightSum / cols);
  final rawCentroidY = toFrameY(weightedY / weightSum / rows);

  // Region bounding box, in raw grid-normalized coordinates.
  var minCol = cols;
  var maxCol = -1;
  var minRow = rows;
  var maxRow = -1;
  for (final cell in best) {
    final cx = cell % cols;
    final cy = cell ~/ cols;
    if (cx < minCol) minCol = cx;
    if (cx > maxCol) maxCol = cx;
    if (cy < minRow) minRow = cy;
    if (cy > maxRow) maxRow = cy;
  }

  final centroid = rotatePointToDisplaySpace(
    x: rawCentroidX,
    y: rawCentroidY,
    sensorOrientationDegrees: frame.sensorOrientationDegrees,
    mirror: frame.isFrontFacing,
  );
  return FrameExtreme(
    point: FramePoint(
      normalizedX: centroid.x,
      normalizedY: centroid.y,
      luma: coreLuma.round().clamp(0, 255),
    ),
    meanLuma: bestMean,
    bounds: _rotateRectToDisplaySpace(
      left: toFrameX(minCol / cols),
      top: toFrameY(minRow / rows),
      right: toFrameX((maxCol + 1) / cols),
      bottom: toFrameY((maxRow + 1) / rows),
      frame: frame,
    ),
  );
}

void _visit(
  int cell,
  int label,
  List<int> labels,
  List<int> stack,
  bool Function(int) inMask,
) {
  if (labels[cell] != -1 || !inMask(cell)) return;
  labels[cell] = label;
  stack.add(cell);
}

double _regionMean(List<int> cells, List<double> mean) {
  var sum = 0.0;
  for (final cell in cells) {
    sum += mean[cell];
  }
  return sum / cells.length;
}

/// The most extreme (highest for [bright], lowest otherwise) cell mean in
/// a region.
double _regionExtremeCell(
  List<int> cells,
  List<double> mean, {
  required bool bright,
}) {
  var extreme = bright ? 0.0 : 255.0;
  for (final cell in cells) {
    final m = mean[cell];
    if (m < 0) continue;
    if (bright ? m > extreme : m < extreme) extreme = m;
  }
  return extreme;
}

/// Rotates (and mirrors) an axis-aligned rect from raw sensor-normalized
/// space into display space by transforming its corners - the rect stays
/// axis-aligned because the rotation is always a multiple of 90 degrees.
NormalizedRect _rotateRectToDisplaySpace({
  required double left,
  required double top,
  required double right,
  required double bottom,
  required RawCameraFrame frame,
}) {
  var minX = 1.0;
  var minY = 1.0;
  var maxX = 0.0;
  var maxY = 0.0;
  for (final corner in [
    [left, top],
    [right, top],
    [right, bottom],
    [left, bottom],
  ]) {
    final p = rotatePointToDisplaySpace(
      x: corner[0],
      y: corner[1],
      sensorOrientationDegrees: frame.sensorOrientationDegrees,
      mirror: frame.isFrontFacing,
    );
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  return NormalizedRect(left: minX, top: minY, right: maxX, bottom: maxY);
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
