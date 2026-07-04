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
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildPreview(),
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

  Widget _buildPreview() {
    final controller = viewModel.repository.controller;
    if (viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            viewModel.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    final preview = FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
    if (!enhanceColors) return preview;
    return ColorFiltered(
      colorFilter: buildEnhanceColorPreviewFilter(),
      child: preview,
    );
  }
}
