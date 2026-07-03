import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/frame_point.dart';

/// The Camera sector: live preview plus the camera-swap, light and
/// snapshot controls, and optional brightest/darkest point overlays.
class CameraSectorWidget extends StatelessWidget {
  const CameraSectorWidget({
    required this.viewModel,
    required this.onSnapshot,
    super.key,
    this.brightestPoint,
    this.darkestPoint,
    this.showBrightestPoint = false,
    this.showDarkestPoint = false,
  });

  final CameraViewModel viewModel;
  final VoidCallback onSnapshot;
  final FramePoint? brightestPoint;
  final FramePoint? darkestPoint;
  final bool showBrightestPoint;
  final bool showDarkestPoint;

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
              if (showBrightestPoint && brightestPoint != null)
                _positionedMarker(
                  point: brightestPoint!,
                  color: Colors.black,
                  constraints: constraints,
                ),
              if (showDarkestPoint && darkestPoint != null)
                _positionedMarker(
                  point: darkestPoint!,
                  color: Colors.white,
                  constraints: constraints,
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: TranslucentIconButton(
                  icon: Icons.cameraswitch_outlined,
                  semanticLabel: 'Swap camera',
                  onPressed: viewModel.switchLens,
                ),
              ),
              Positioned(
                left: 8,
                bottom: 60,
                child: TranslucentIconButton(
                  icon: viewModel.isTorchOn
                      ? Icons.flash_on
                      : Icons.flash_off_outlined,
                  semanticLabel: 'Toggle light',
                  isActive: viewModel.isTorchOn,
                  onPressed: viewModel.toggleTorch,
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: TranslucentIconButton(
                  icon: Icons.camera_alt_outlined,
                  semanticLabel: 'Snapshot',
                  onPressed: onSnapshot,
                ),
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
