import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/snapshot/domain/snapshot_repository.dart';

/// Saves a full-screen snapshot to the device photo gallery using `gal`.
class SnapshotRepositoryImpl implements SnapshotRepository {
  SnapshotRepositoryImpl({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  @override
  Future<void> captureAndSave(GlobalKey boundaryKey) async {
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw const SnapshotFailure(
        'Nothing to capture - screen is not ready yet',
      );
    }

    try {
      await _ensureStorageAccess();

      final image = await renderObject.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw const SnapshotFailure('Failed to encode snapshot as PNG');
      }

      final bytes = byteData.buffer.asUint8List();
      await Gal.putImageBytes(bytes, album: 'SimplySpectrum');
    } on SnapshotFailure {
      rethrow;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to capture/save snapshot',
        error: error,
        stackTrace: stackTrace,
      );
      throw SnapshotFailure('Unable to save snapshot: $error');
    }
  }

  /// Ensures the app has permission to write to the device photo gallery.
  ///
  /// On Android, uses `permission_handler` instead of `gal`'s built-in
  /// permission flow. `gal` only requests `WRITE_EXTERNAL_STORAGE` alone,
  /// which fails silently on some Android 9/10 OEM ROMs \u2014 the system
  /// dialog appears and the user taps "Allow", but the permission is
  /// never actually granted, so `Gal.hasAccess()` stays false forever.
  /// `permission_handler` requests both `READ_EXTERNAL_STORAGE` and
  /// `WRITE_EXTERNAL_STORAGE` together (when both are declared in the
  /// manifest), which works reliably on all OEM ROMs.
  ///
  /// On Android 11+ (API 30+), scoped storage makes storage permissions a
  /// no-op, so `permission_handler` returns granted automatically.
  ///
  /// On iOS, uses `gal`'s built-in permission flow (Photo Library access).
  Future<void> _ensureStorageAccess() async {
    if (Platform.isAndroid) {
      final status = await ph.Permission.storage.request();
      if (!status.isGranted) {
        throw const SnapshotFailure(
          'Photo library access was denied, cannot save snapshot',
        );
      }
      return;
    }

    // iOS / other platforms: use gal's built-in permission flow.
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw const SnapshotFailure(
          'Photo library access was denied, cannot save snapshot',
        );
      }
    }
  }
}
