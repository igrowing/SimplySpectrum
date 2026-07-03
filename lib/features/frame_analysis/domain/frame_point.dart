import 'package:equatable/equatable.dart';

/// A point of interest within a frame, expressed as normalized coordinates
/// (0.0-1.0 on each axis) so overlays can be positioned correctly on the
/// preview widget regardless of its actual rendered size.
class FramePoint extends Equatable {
  const FramePoint({
    required this.normalizedX,
    required this.normalizedY,
    required this.luma,
  });

  final double normalizedX;
  final double normalizedY;

  /// Raw luma (0-255) at this point, useful for tests/debugging.
  final int luma;

  @override
  List<Object?> get props => [normalizedX, normalizedY, luma];
}
