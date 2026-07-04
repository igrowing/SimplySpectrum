import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/color_enhance_filter.dart';

void main() {
  group('buildEnhanceColorPreviewFilter', () {
    test('returns a usable ColorFilter without throwing', () {
      expect(buildEnhanceColorPreviewFilter, returnsNormally);
      expect(buildEnhanceColorPreviewFilter(), isA<ColorFilter>());
    });

    test('is stable across calls (same boost constants every time)', () {
      // ColorFilter is Equatable-ish (value equality via ==), so two
      // filters built from the same fixed boost constants should compare
      // equal - this guards against the matrix silently becoming
      // non-deterministic.
      expect(
        buildEnhanceColorPreviewFilter(),
        buildEnhanceColorPreviewFilter(),
      );
    });
  });
}
