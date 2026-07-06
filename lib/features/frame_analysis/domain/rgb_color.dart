import 'package:equatable/equatable.dart';

/// A simple sampled RGB color (0-255 per channel), pure-Dart so it can be
/// produced by `analyzeFrame` (see `frame_analyzer.dart`) and carried up
/// through the domain layer without any Flutter dependency. See
/// `color_conversions.dart` for the CMYK/Lab conversions built on top of
/// this.
class RgbColor extends Equatable {
  const RgbColor({required this.r, required this.g, required this.b});

  /// 0-255.
  final int r;

  /// 0-255.
  final int g;

  /// 0-255.
  final int b;

  /// `#rrggbb`, lowercase, always 6 hex digits.
  String get hex =>
      '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';

  @override
  List<Object?> get props => [r, g, b];
}
