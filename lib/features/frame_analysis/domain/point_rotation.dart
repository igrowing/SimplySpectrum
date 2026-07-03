/// Rotates (and optionally mirrors) a normalized (0.0-1.0) point from the
/// raw camera sensor's pixel space into the space the platform's
/// `CameraPreview` widget actually displays.
///
/// The `camera` plugin's image stream always delivers frames in the
/// sensor's native, unrotated orientation, while `CameraPreview`
/// auto-rotates (and, for the front lens, mirrors) what appears on
/// screen. A point of interest computed from raw sample coordinates -
/// e.g. the brightest/darkest sampled pixel - must go through this same
/// transform before it's positioned as an overlay, or it drifts away
/// from the feature it's meant to mark on any device whose sensor isn't
/// mounted at 0 degrees, which in practice is almost every phone/tablet.
///
/// [sensorOrientationDegrees] is the clockwise rotation
/// (`CameraDescription.sensorOrientation` on Android: one of 0/90/180/270)
/// needed to turn the raw buffer into the correctly-oriented display
/// image. [mirror] additionally flips the result horizontally, which the
/// front/selfie lens's preview does relative to its raw buffer.
({double x, double y}) rotatePointToDisplaySpace({
  required double x,
  required double y,
  required int sensorOrientationDegrees,
  required bool mirror,
}) {
  var dx = x;
  var dy = y;
  switch (sensorOrientationDegrees % 360) {
    case 90:
      // Rotating the raw image 90 degrees clockwise sends its top-left
      // corner (0,0) to the top-right corner (1,0) of the display image.
      final rotatedX = 1 - y;
      final rotatedY = x;
      dx = rotatedX;
      dy = rotatedY;
    case 180:
      dx = 1 - x;
      dy = 1 - y;
    case 270:
      // The inverse of the 90-degree case above.
      final rotatedX = y;
      final rotatedY = 1 - x;
      dx = rotatedX;
      dy = rotatedY;
    default:
      // 0 degrees: no rotation needed.
      break;
  }
  if (mirror) {
    dx = 1 - dx;
  }
  return (x: dx, y: dy);
}
