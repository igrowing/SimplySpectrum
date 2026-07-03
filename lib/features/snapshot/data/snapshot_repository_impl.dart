import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';

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
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          throw const SnapshotFailure(
            'Photo library access was denied, cannot save snapshot',
          );
        }
      }

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
}
