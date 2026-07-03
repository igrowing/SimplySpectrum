import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Pixel encoding of a [RawCameraFrame]'s plane data.
enum RawFrameFormat {
  /// Planar/semi-planar YUV 4:2:0 (one luma plane + two, possibly
  /// interleaved, chroma planes).
  yuv420,

  /// Packed 32bpp BGRA, one plane, 4 bytes per pixel.
  bgra8888,
}

/// A single decoded plane of image data, independent of any platform SDK
/// type. Kept pure Dart so the analysis domain never depends on Flutter or
/// plugin packages.
class RawFramePlane extends Equatable {
  const RawFramePlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.pixelStride,
  });

  final Uint8List bytes;
  final int bytesPerRow;

  /// Distance in bytes between two horizontally adjacent samples in this
  /// plane. For a fully planar Y/U/V layout this is 1; for semi-planar
  /// interleaved chroma (e.g. NV12/NV21-style U/V) it is typically 2.
  final int pixelStride;

  @override
  List<Object?> get props => [bytes, bytesPerRow, pixelStride];
}

/// A camera frame decoupled from the `camera` plugin's `CameraImage`.
///
/// The data layer is responsible for translating plugin-specific frame
/// objects into this pure model before handing them to domain-level
/// analysis code (histogram building, wavelength/luminosity estimation).
class RawCameraFrame extends Equatable {
  const RawCameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
  });

  final int width;
  final int height;
  final RawFrameFormat format;

  /// For [RawFrameFormat.yuv420]: `[Y, U, V]`.
  /// For [RawFrameFormat.bgra8888]: a single packed plane.
  final List<RawFramePlane> planes;

  @override
  List<Object?> get props => [width, height, format, planes];
}
