import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';

RawFramePlane _plane({int length = 4, int bytesPerRow = 2, int stride = 1}) =>
    RawFramePlane(
      bytes: Uint8List(length),
      bytesPerRow: bytesPerRow,
      pixelStride: stride,
    );

void main() {
  group('RawFramePlane', () {
    test('equality is structural over bytes/bytesPerRow/pixelStride', () {
      final a = RawFramePlane(
        bytes: Uint8List.fromList([1, 2, 3]),
        bytesPerRow: 3,
        pixelStride: 1,
      );
      final b = RawFramePlane(
        bytes: Uint8List.fromList([1, 2, 3]),
        bytesPerRow: 3,
        pixelStride: 1,
      );
      final differentBytes = RawFramePlane(
        bytes: Uint8List.fromList([1, 2, 9]),
        bytesPerRow: 3,
        pixelStride: 1,
      );

      expect(a, b);
      expect(a == differentBytes, isFalse);
    });
  });

  group('RawCameraFrame', () {
    test('defaults sensorOrientationDegrees to 0 and isFrontFacing to '
        'false', () {
      final frame = RawCameraFrame(
        width: 4,
        height: 4,
        format: RawFrameFormat.yuv420,
        planes: [_plane(), _plane(), _plane()],
      );

      expect(frame.sensorOrientationDegrees, 0);
      expect(frame.isFrontFacing, isFalse);
    });

    test('stores width, height, format and explicit orientation/mirror '
        'flags', () {
      final frame = RawCameraFrame(
        width: 640,
        height: 480,
        format: RawFrameFormat.bgra8888,
        planes: [_plane(length: 640 * 480 * 4)],
        sensorOrientationDegrees: 90,
        isFrontFacing: true,
      );

      expect(frame.width, 640);
      expect(frame.height, 480);
      expect(frame.format, RawFrameFormat.bgra8888);
      expect(frame.planes, hasLength(1));
      expect(frame.sensorOrientationDegrees, 90);
      expect(frame.isFrontFacing, isTrue);
    });

    test('equality is structural across every prop, not identity', () {
      RawCameraFrame build() => RawCameraFrame(
        width: 4,
        height: 4,
        format: RawFrameFormat.yuv420,
        planes: [_plane(), _plane(), _plane()],
        sensorOrientationDegrees: 90,
      );

      expect(build(), build());
    });

    test('two frames differing only by sensorOrientationDegrees are not '
        'equal', () {
      final planes = [_plane(), _plane(), _plane()];
      final a = RawCameraFrame(
        width: 4,
        height: 4,
        format: RawFrameFormat.yuv420,
        planes: planes,
      );
      final b = RawCameraFrame(
        width: 4,
        height: 4,
        format: RawFrameFormat.yuv420,
        planes: planes,
        sensorOrientationDegrees: 180,
      );

      expect(a == b, isFalse);
    });

    test('two frames differing only by isFrontFacing are not equal', () {
      final planes = [_plane(), _plane(), _plane()];
      final a = RawCameraFrame(
        width: 4,
        height: 4,
        format: RawFrameFormat.yuv420,
        planes: planes,
      );
      final b = RawCameraFrame(
        width: 4,
        height: 4,
        format: RawFrameFormat.yuv420,
        planes: planes,
        isFrontFacing: true,
      );

      expect(a == b, isFalse);
    });
  });
}
