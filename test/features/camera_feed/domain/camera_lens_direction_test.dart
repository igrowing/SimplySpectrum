import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_lens_direction.dart';

void main() {
  group('CameraLensDirection.opposite', () {
    test('rear flips to front', () {
      expect(CameraLensDirection.rear.opposite, CameraLensDirection.front);
    });

    test('front flips to rear', () {
      expect(CameraLensDirection.front.opposite, CameraLensDirection.rear);
    });
  });
}
