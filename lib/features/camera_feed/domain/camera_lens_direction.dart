/// Which physical camera is currently feeding the preview.
///
/// Only the two lenses relevant to handheld phones/tablets are modeled —
/// this app targets mobile devices with a camera only (no TV/car/wearable
/// hardware), so there is no notion of external or depth cameras here.
enum CameraLensDirection {
  rear,
  front;

  CameraLensDirection get opposite =>
      this == rear ? CameraLensDirection.front : CameraLensDirection.rear;
}
