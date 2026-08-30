import 'package:equatable/equatable.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';

/// An axis-aligned rectangle in normalized (0.0-1.0) display-space
/// coordinates - the bounding box of a detected bright/dark region.
///
/// The presentation layer uses it to decide whether two successive
/// detections refer to the *same* region (rather than comparing raw
/// centroid coordinates, which jitter within a region frame to frame) -
/// see the extreme-spot smoother in `AnalysisViewModel`.
class NormalizedRect extends Equatable {
  const NormalizedRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory NormalizedRect.lerp(NormalizedRect a, NormalizedRect b, double t) =>
      NormalizedRect(
        left: a.left + (b.left - a.left) * t,
        top: a.top + (b.top - a.top) * t,
        right: a.right + (b.right - a.right) * t,
        bottom: a.bottom + (b.bottom - a.bottom) * t,
      );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get width => (right - left).abs();
  double get height => (bottom - top).abs();
  double get area => width * height;

  NormalizedRect inflated(double margin) => NormalizedRect(
    left: left - margin,
    top: top - margin,
    right: right + margin,
    bottom: bottom + margin,
  );

  /// Fraction of the *smaller* of the two rectangles that lies inside the
  /// other: 0.0 = disjoint, 1.0 = one fully contains the other. Used as a
  /// scale-independent "are these the same region?" test.
  double overlapFraction(NormalizedRect other) {
    final ix =
        (right < other.right ? right : other.right) -
        (left > other.left ? left : other.left);
    final iy =
        (bottom < other.bottom ? bottom : other.bottom) -
        (top > other.top ? top : other.top);
    if (ix <= 0 || iy <= 0) return 0;
    final intersection = ix * iy;
    final minArea = area < other.area ? area : other.area;
    return minArea <= 0 ? 0 : intersection / minArea;
  }

  @override
  List<Object?> get props => [left, top, right, bottom];
}

/// A detected extreme-luminance region within a frame.
///
/// [point] is the marker position: the luma-weighted centroid of the most
/// extreme cells in the region (not a single hottest/coldest pixel).
/// [meanLuma] is the mean luma over the whole region, used by the
/// presentation-layer smoother to decide when a genuinely brighter/darker
/// region has appeared and the marker should relocate. [bounds] is the
/// region's extent. All three are in the auto-rotated display coordinate
/// space the `CameraPreview` widget uses.
class FrameExtreme extends Equatable {
  const FrameExtreme({
    required this.point,
    required this.meanLuma,
    required this.bounds,
  });

  final FramePoint point;
  final double meanLuma;
  final NormalizedRect bounds;

  @override
  List<Object?> get props => [point, meanLuma, bounds];
}
