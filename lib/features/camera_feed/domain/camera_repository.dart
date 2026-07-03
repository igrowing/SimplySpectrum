import 'package:simply_spectrum/features/camera_feed/domain/camera_lens_direction.dart';
import 'package:simply_spectrum/features/camera_feed/domain/raw_camera_frame.dart';

/// Behavioral contract for driving the device camera.
///
/// This is intentionally narrow and pure-Dart-friendly: it only exposes
/// what the analysis/business logic needs (frame stream, lens switching,
/// torch control). Building the actual live preview widget is a
/// presentation-layer concern that talks to the concrete implementation
/// directly, since Flutter's camera preview widget requires the plugin's
/// own controller type.
abstract class CameraRepository {
  /// Emits decoded frames while streaming is active.
  Stream<RawCameraFrame> get frameStream;

  /// Currently active lens, or null before [initialize] completes.
  CameraLensDirection? get currentLens;

  /// Whether the device's torch/LED is currently on.
  bool get isTorchOn;

  /// Opens the camera on the given lens and starts the frame stream.
  Future<void> initialize({
    CameraLensDirection lens = CameraLensDirection.rear,
  });

  /// Switches to the other lens (rear <-> front), preserving stream state.
  Future<void> switchLens();

  /// Turns the rear LED torch on/off. No-op with a thrown StateError is
  /// avoided per error-handling rules; callers should catch and surface
  /// a CameraFailure instead - implementations must not throw silently.
  Future<void> setTorchEnabled(bool enabled);

  /// Releases camera hardware resources.
  Future<void> dispose();
}
