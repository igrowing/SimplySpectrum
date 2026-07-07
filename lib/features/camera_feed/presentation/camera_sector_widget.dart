import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/color_enhance_filter.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';

/// The Camera sector: just the live preview plus the optional
/// brightest/darkest point overlays. The swap/light/snapshot controls
/// live in the Controls sector instead, keeping this sector uncluttered.
class CameraSectorWidget extends StatelessWidget {
  const CameraSectorWidget({
    required this.viewModel,
    super.key,
    this.brightestPoint,
    this.darkestPoint,
    this.showExtremeLightSpots = false,
    this.enhanceColors = false,
  });

  final CameraViewModel viewModel;
  final FramePoint? brightestPoint;
  final FramePoint? darkestPoint;
  final bool showExtremeLightSpots;

  /// Mirrors the "Enhance colors" setting into the live preview itself
  /// (see `color_enhance_filter.dart`), not just the analysis pipeline -
  /// so what's on screen visually matches what's being measured.
  final bool enhanceColors;

  @override
  Widget build(BuildContext context) {
    // The idle-state background (only ever visible before the camera is
    // ready, or on error - the live preview itself always fully covers
    // this box via BoxFit.cover) follows the theme like the rest of the
    // sector grid's chrome. The brightest/darkest markers below stay a
    // fixed black/white regardless: they're annotations drawn directly
    // on the photographed scene (as documented in Settings: "black
    // circle = brightest, white circle = darkest"), not app chrome, so
    // they shouldn't flip with the theme any more than the video itself
    // does.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildPreview(constraints),
              if (showExtremeLightSpots && brightestPoint != null)
                _positionedMarker(
                  point: brightestPoint!,
                  color: Colors.black,
                  constraints: constraints,
                ),
              if (showExtremeLightSpots && darkestPoint != null)
                _positionedMarker(
                  point: darkestPoint!,
                  color: Colors.white,
                  constraints: constraints,
                ),
              // A transient notice (e.g. "torch is only available on the
              // rear lens") floats over the still-live preview and clears
              // itself after a few seconds (see CameraViewModel) - it
              // must never replace `_buildPreview()` outright, or the
              // feed would appear to freeze/go black until the message
              // happened to be dismissed by some later action.
              if (viewModel.transientMessage != null)
                _transientMessageBanner(viewModel.transientMessage!),
            ],
          );
        },
      ),
    );
  }

  Positioned _positionedMarker({
    required FramePoint point,
    required Color color,
    required BoxConstraints constraints,
  }) {
    return Positioned(
      left: point.normalizedX * constraints.maxWidth - 6,
      top: point.normalizedY * constraints.maxHeight - 6,
      child: IgnorePointer(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _transientMessageBanner(String message) {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BoxConstraints constraints) {
    final controller = viewModel.repository.controller;
    if (viewModel.errorMessage != null) {
      return Center(
        child: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              viewModel.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }
    if (!viewModel.isReady || controller == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    // `CameraPreview` already computes its own correct AspectRatio
    // internally for whatever the CURRENT device orientation actually
    // is (see the `camera` package's CameraPreview.build(): it inverts
    // controller.value.aspectRatio for portrait vs landscape and, on
    // Android, wraps the texture in a RotatedBox by the right number of
    // quarter turns). It does NOT need any help from us to rotate or
    // reshape the image - previously this widget forced an outer
    // SizedBox with previewSize.width/height hard-swapped, which only
    // matched the portrait case; in landscape that swap fought against
    // CameraPreview's own (correct) sizing and squeezed/stretched the
    // texture into the wrong box.
    //
    // The fix: give CameraPreview *loose but bounded* constraints (this
    // sector's own box) via ConstrainedBox rather than SizedBox's tight
    // ones - AspectRatio then computes its true, correctly-oriented
    // "contain" size within that box, and the outer FittedBox(cover)
    // uniformly scales that correctly-shaped result up to fill the
    // sector, cropping only the unavoidable overflow (the same
    // necessary edge-cropping any "fill the screen without letterbox
    // bars" preview does) - never distorting the aspect ratio itself.
    final preview = ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
          ),
          child: CameraPreview(controller),
        ),
      ),
    );
    if (!enhanceColors) return preview;
    return ColorFiltered(
      colorFilter: buildEnhanceColorPreviewFilter(),
      child: preview,
    );
  }
}
