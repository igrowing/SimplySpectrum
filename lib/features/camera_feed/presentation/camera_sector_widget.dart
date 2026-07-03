import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
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
  });

  final CameraViewModel viewModel;
  final FramePoint? brightestPoint;
  final FramePoint? darkestPoint;
  final bool showExtremeLightSpots;

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
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }
}
