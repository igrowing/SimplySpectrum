import 'package:flutter/widgets.dart';

/// Captures the current screen (via a [RepaintBoundary] key) and saves it
/// as an image, e.g. to the device photo gallery.
///
/// This lives in "domain" only in the loose sense of being the feature's
/// behavioral contract - it necessarily depends on Flutter's [GlobalKey]
/// since screenshotting is inherently a rendering-tree concern, unlike the
/// analysis domains which stay pure Dart.
abstract class SnapshotRepository {
  Future<void> captureAndSave(GlobalKey boundaryKey);
}
