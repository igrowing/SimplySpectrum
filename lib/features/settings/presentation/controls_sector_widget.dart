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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TranslucentIconButton(
                  icon: Icons.cameraswitch_outlined,
                  semanticLabel: 'Swap camera',
                  onPressed: viewModel.switchLens,
                ),
                const SizedBox(width: 16),
                TranslucentIconButton(
                  icon: viewModel.isTorchOn
                      ? Icons.flash_on
                      : Icons.flash_off_outlined,
                  semanticLabel: 'Toggle light',
                  isActive: viewModel.isTorchOn,
                  onPressed: viewModel.toggleTorch,
                ),
                const SizedBox(width: 16),
                TranslucentIconButton(
                  icon: Icons.camera_alt_outlined,
                  semanticLabel: 'Snapshot',
                  onPressed: widget.onSnapshot,
                ),
              ],
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
