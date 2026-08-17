import 'package:flutter/services.dart';

/// Thin platform channel for native features that don't warrant a
/// full plugin: screen wakelock and gallery path query.
///
/// Channel name: `simply_spectrum/platform`.
class PlatformService {
  PlatformService._();

  static const _channel = MethodChannel('simply_spectrum/platform');

  /// Toggles the screen wakelock (keep screen on).
  ///
  /// Android: sets/clears `FLAG_KEEP_SCREEN_ON` on the activity window.
  /// iOS: toggles `UIApplication.isIdleTimerDisabled`.
  static Future<void> setWakelock(bool enabled) async {
    await _channel.invokeMethod<void>('setWakelock', {'enabled': enabled});
  }

  /// Returns the directory where gallery images are stored on disk.
  ///
  /// Android: `/storage/emulated/0/Pictures` (the public Pictures
  /// directory; the album subfolder is appended by the caller).
  /// iOS: returns a human-readable label like
  /// `Photos album "SimplySpectrum"` since Photo Library assets don't
  /// have a traditional file-system path.
  static Future<String> getGalleryPath() async {
    final result = await _channel.invokeMethod<String>('getGalleryPath');
    return result ?? '';
  }
}
