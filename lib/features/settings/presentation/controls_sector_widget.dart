import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/color_conversions.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The Controls sector: the average-color readout plus large camera
/// controls (swap lens, torch, snapshot, freeze) and small "keep screen
/// on"/"open settings" toggles. Detailed settings switches live on their
/// own full [SettingsScreen] instead, keeping this sector uncluttered.
class ControlsSectorWidget extends StatefulWidget {
  const ControlsSectorWidget({
    required this.viewModel,
    required this.onSnapshot,
    super.key,
    this.averageColor,
  });

  final CameraViewModel viewModel;
  final VoidCallback onSnapshot;

  /// Mean color of the most recently analyzed frame (null before the
  /// first frame is analyzed), rendered as the RGB/CMYK/LAB readout box.
  final RgbColor? averageColor;

  @override
  State<ControlsSectorWidget> createState() => _ControlsSectorWidgetState();
}

class _ControlsSectorWidgetState extends State<ControlsSectorWidget> {
  bool _keepScreenOn = false;

  /// Icon size for the 4 main controls when this sector's own box is
  /// taller than it is wide (the "vertical" case): stacking them in a
  /// [Column] frees up room to make them noticeably larger than the
  /// fixed horizontal-layout size.
  static const double _verticalIconSize = 32;
  static const double _verticalPadding = 14;

  static const TextStyle _labelStyle = TextStyle(
    color: Colors.white70,
    fontSize: 8,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  Future<void> _toggleKeepScreenOn() async {
    final next = !_keepScreenOn;
    await WakelockPlus.toggle(enable: next);
    if (mounted) setState(() => _keepScreenOn = next);
  }

  @override
  void dispose() {
    // Never leave the screen forced on after this sector is torn down.
    if (_keepScreenOn) {
      unawaited(WakelockPlus.disable());
    }
    super.dispose();
  }

  /// A main control button with its word label stacked below the icon,
  /// in both the horizontal and vertical (stacked) layouts - only the
  /// icon/padding size changes between them, via [large].
  Widget _labeledButton({
    required IconData icon,
    required String semanticLabel,
    required String label,
    required VoidCallback onPressed,
    required bool large,
    bool isActive = false,
  }) {
    final button = TranslucentIconButton(
      icon: icon,
      semanticLabel: semanticLabel,
      isActive: isActive,
      iconSize: large ? _verticalIconSize : 22,
      padding: large
          ? const EdgeInsets.all(_verticalPadding)
          : const EdgeInsets.all(10),
      onPressed: onPressed,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 3),
        Text(label, style: _labelStyle),
      ],
    );
  }

  List<Widget> _mainButtons(CameraViewModel viewModel, {required bool large}) {
    final isFrozen = viewModel.isFrozen;
    return [
      _labeledButton(
        icon: Icons.cameraswitch_outlined,
        semanticLabel: 'Swap camera',
        label: 'SWAP',
        large: large,
        onPressed: viewModel.switchLens,
      ),
      _labeledButton(
        icon: viewModel.isTorchOn
            ? Icons.flashlight_on
            : Icons.flashlight_off_outlined,
        semanticLabel: 'Toggle light',
        label: 'TORCH',
        isActive: viewModel.isTorchOn,
        large: large,
        onPressed: viewModel.toggleTorch,
      ),
      _labeledButton(
        icon: Icons.camera_alt_outlined,
        semanticLabel: 'Snapshot',
        label: 'SNAP',
        large: large,
        onPressed: widget.onSnapshot,
      ),
      _labeledButton(
        icon: isFrozen ? Icons.play_arrow : Icons.ac_unit,
        semanticLabel: isFrozen ? 'Resume' : 'Freeze',
        label: isFrozen ? 'RESUME' : 'FREEZE',
        isActive: isFrozen,
        large: large,
        onPressed: viewModel.toggleFreeze,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return ColoredBox(
      color: const Color(0xFF101014),
      child: Stack(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              'Controls',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // This sector's own box, not the device orientation - it
                // stays consistent with how the rest of the app sizes
                // itself off available constraints rather than raw
                // screen/hardware queries.
                final isVertical = constraints.maxHeight > constraints.maxWidth;
                final buttons = _mainButtons(viewModel, large: isVertical);
                final colorBox = _AverageColorBox(color: widget.averageColor);

                if (isVertical) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      colorBox,
                      const SizedBox(height: 12),
                      buttons[0],
                      const SizedBox(height: 14),
                      buttons[1],
                      const SizedBox(height: 14),
                      buttons[2],
                      const SizedBox(height: 14),
                      buttons[3],
                    ],
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    colorBox,
                    const SizedBox(width: 14),
                    buttons[0],
                    const SizedBox(width: 14),
                    buttons[1],
                    const SizedBox(width: 14),
                    buttons[2],
                    const SizedBox(width: 14),
                    buttons[3],
                  ],
                );
              },
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TranslucentIconButton(
                  icon: _keepScreenOn
                      ? Icons.brightness_high
                      : Icons.brightness_low_outlined,
                  semanticLabel: 'Keep screen on',
                  isActive: _keepScreenOn,
                  iconSize: 16,
                  padding: const EdgeInsets.all(7),
                  onPressed: _toggleKeepScreenOn,
                ),
                const SizedBox(width: 8),
                TranslucentIconButton(
                  icon: Icons.settings_outlined,
                  semanticLabel: 'Settings',
                  iconSize: 16,
                  padding: const EdgeInsets.all(7),
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The average-color readout: a swatch of the currently detected mean
/// color with its RGB/CMYK/LAB values printed on top, in a text color
/// chosen for contrast against that swatch.
class _AverageColorBox extends StatelessWidget {
  const _AverageColorBox({required this.color});

  final RgbColor? color;

  @override
  Widget build(BuildContext context) {
    final sampled = color;
    if (sampled == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'Detecting color…',
          style: TextStyle(color: Colors.white54, fontSize: 9),
        ),
      );
    }

    final cmyk = rgbToCmyk(sampled);
    final lab = rgbToLab(sampled);
    // Lab lightness (0-100) is a perceptually-meaningful "how dark is
    // this color" measure we already have on hand - below the midpoint
    // reads as dark, so white text stays legible on it.
    final textColor = lab.l < 50 ? Colors.white : Colors.black;
    final textStyle = TextStyle(
      color: textColor,
      fontSize: 9,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.4,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, sampled.r, sampled.g, sampled.b),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RGB: ${sampled.hex}', style: textStyle),
          Text(
            'CMYK: ${cmyk.c}/${cmyk.m}/${cmyk.y}/${cmyk.k}',
            style: textStyle,
          ),
          Text('LAB: ${lab.l},${lab.a},${lab.b}', style: textStyle),
        ],
      ),
    );
  }
}
