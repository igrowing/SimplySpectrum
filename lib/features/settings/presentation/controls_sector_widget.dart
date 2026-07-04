import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The Controls sector: large camera controls (swap lens, torch,
/// snapshot) plus small "keep screen on" and "open settings" toggles.
/// Replaces the old, over-dense Settings sector - the actual settings
/// switches now live on their own full [SettingsScreen].
class ControlsSectorWidget extends StatefulWidget {
  const ControlsSectorWidget({
    required this.viewModel,
    required this.onSnapshot,
    super.key,
  });

  final CameraViewModel viewModel;
  final VoidCallback onSnapshot;

  @override
  State<ControlsSectorWidget> createState() => _ControlsSectorWidgetState();
}

class _ControlsSectorWidgetState extends State<ControlsSectorWidget> {
  bool _keepScreenOn = false;

  /// Icon size for the 3 main controls when this sector's own box is
  /// taller than it is wide (the "vertical" case): stacking them in a
  /// [Column] frees up room to make them noticeably larger than the
  /// fixed horizontal-layout size.
  static const double _verticalIconSize = 32;
  static const double _verticalPadding = 14;

  static const TextStyle _labelStyle = TextStyle(
    color: Colors.white70,
    fontSize: 10,
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

  /// A main control button with its word label - stacked below the icon
  /// in the horizontal layout, or placed to the icon's right in the
  /// vertical (stacked) layout.
  Widget _labeledButton({
    required IconData icon,
    required String semanticLabel,
    required String label,
    required VoidCallback onPressed,
    required bool large,
    required bool vertical,
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
    final labelText = Text(label, style: _labelStyle);

    if (vertical) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [button, const SizedBox(width: 10), labelText],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [button, const SizedBox(height: 4), labelText],
    );
  }

  List<Widget> _mainButtons(
    CameraViewModel viewModel, {
    required bool large,
    required bool vertical,
  }) {
    return [
      _labeledButton(
        icon: Icons.cameraswitch_outlined,
        semanticLabel: 'Swap camera',
        label: 'SWAP',
        large: large,
        vertical: vertical,
        onPressed: viewModel.switchLens,
      ),
      _labeledButton(
        icon: viewModel.isTorchOn ? Icons.flash_on : Icons.flash_off_outlined,
        semanticLabel: 'Toggle light',
        label: 'TORCH',
        isActive: viewModel.isTorchOn,
        large: large,
        vertical: vertical,
        onPressed: viewModel.toggleTorch,
      ),
      _labeledButton(
        icon: Icons.camera_alt_outlined,
        semanticLabel: 'Snapshot',
        label: 'SNAP',
        large: large,
        vertical: vertical,
        onPressed: widget.onSnapshot,
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
                final buttons = _mainButtons(
                  viewModel,
                  large: isVertical,
                  vertical: isVertical,
                );

                if (isVertical) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buttons[0],
                      const SizedBox(height: 16),
                      buttons[1],
                      const SizedBox(height: 16),
                      buttons[2],
                    ],
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buttons[0],
                    const SizedBox(width: 16),
                    buttons[1],
                    const SizedBox(width: 16),
                    buttons[2],
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
