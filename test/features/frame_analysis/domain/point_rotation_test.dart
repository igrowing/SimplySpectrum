import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/point_rotation.dart';

void main() {
  group('rotatePointToDisplaySpace', () {
    test('0 degrees, no mirror: point is unchanged', () {
      final result = rotatePointToDisplaySpace(
        x: 0.2,
        y: 0.8,
        sensorOrientationDegrees: 0,
        mirror: false,
      );

      expect(result.x, 0.2);
      expect(result.y, 0.8);
    });

    test('90 degrees: raw top-left maps to display top-right', () {
      final result = rotatePointToDisplaySpace(
        x: 0,
        y: 0,
        sensorOrientationDegrees: 90,
        mirror: false,
      );

      expect(result.x, 1);
      expect(result.y, 0);
    });

    test('180 degrees: point maps to its diagonal opposite', () {
      final result = rotatePointToDisplaySpace(
        x: 0.1,
        y: 0.9,
        sensorOrientationDegrees: 180,
        mirror: false,
      );

      expect(result.x, closeTo(0.9, 0.0001));
      expect(result.y, closeTo(0.1, 0.0001));
    });

    test('270 degrees: raw top-left maps to display bottom-left', () {
      final result = rotatePointToDisplaySpace(
        x: 0,
        y: 0,
        sensorOrientationDegrees: 270,
        mirror: false,
      );

      expect(result.x, 0);
      expect(result.y, 1);
    });

    test('90 then 270 degrees round-trips back to the original point', () {
      const originalX = 0.3;
      const originalY = 0.7;

      final rotated = rotatePointToDisplaySpace(
        x: originalX,
        y: originalY,
        sensorOrientationDegrees: 90,
        mirror: false,
      );
      final roundTripped = rotatePointToDisplaySpace(
        x: rotated.x,
        y: rotated.y,
        sensorOrientationDegrees: 270,
        mirror: false,
      );

      expect(roundTripped.x, closeTo(originalX, 0.0001));
      expect(roundTripped.y, closeTo(originalY, 0.0001));
    });

    test('mirror flips the horizontal axis after rotation', () {
      final result = rotatePointToDisplaySpace(
        x: 0.2,
        y: 0.5,
        sensorOrientationDegrees: 0,
        mirror: true,
      );

      expect(result.x, closeTo(0.8, 0.0001));
      expect(result.y, 0.5);
    });
  });
}
