import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simply_spectrum/core/services/platform_service.dart';
import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/color_conversions.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_screen.dart';

/// The "thickness" of the average-color strip: its height when it spans
/// the sector's full width (vertical layout), or its width when it spans
/// the sector's full height (horizontal layout).
const double _averageColorStripThickness = 120;

/// The Controls sector: the average-color readout (a full-bleed strip
/// that reads as a continuation of the sector rather than a floating
/// card) plus a 2x2 grid of camera controls (swap lens, torch, snapshot,
/// freeze), a labelled "SCREEN ON" pill bottom-left, and the settings
/// gear bottom-right. Detailed settings switches live on their own full
/// [SettingsScreen] instead, keeping this sector uncluttered.
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
  /// first frame is analyzed), rendered as the RGB/CMYK/LAB readout
  /// strip.
  final RgbColor? averageColor;

  @override
  State<ControlsSectorWidget> createState() => _ControlsSectorWidgetState();
}

class _ControlsSectorWidgetState extends State<ControlsSectorWidget> {
  bool _keepScreenOn = false;

  /// Icon size for the 4 main controls when this sector's own box is
  /// taller than it is wide (the "vertical" case): the taller box frees
  /// up room to make them noticeably larger than the fixed
  /// horizontal-layout size.
  static const double _verticalIconSize = 30;
  static const double _verticalPadding = 12;

  static TextStyle _labelStyle(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    fontSize: 8,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  Future<void> _toggleKeepScreenOn() async {
    final messenger = ScaffoldMessenger.of(context);
    final next = !_keepScreenOn;
    await PlatformService.setWakelock(next);
    if (!mounted) return;
    setState(() => _keepScreenOn = next);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'Keeping the screen on'
                : 'Screen will turn off by system timeout',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// The "keep screen on" toggle: a labelled translucent pill (lightbulb
  /// icon + word), deliberately placed at the opposite corner from the
  /// Settings button so it doesn't read as more navigation chrome. A
  /// filled bulb + brighter fill = on; an outline bulb = off. Long-press
  /// (and screen readers) surface the fuller "Keep screen on" phrasing.
  Widget _keepScreenOnControl() {
    final active = _keepScreenOn;
    final foreground = active ? Colors.black : Colors.white;
    return Tooltip(
      message: 'Keep screen on',
      child: Semantics(
        button: true,
        toggled: active,
        label: 'Keep screen on',
        excludeSemantics: true,
        child: Material(
          color: (active ? Colors.white : Colors.black).withValues(alpha: 0.35),
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _toggleKeepScreenOn,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: foreground,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SCREEN ON',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Never leave the screen forced on after this sector is torn down.
    if (_keepScreenOn) {
      unawaited(PlatformService.setWakelock(false));
    }
    super.dispose();
  }

  /// A main control button with its word label stacked below the icon.
  Widget _labeledButton(
    BuildContext context, {
    required IconData icon,
    required String semanticLabel,
    required String label,
    required VoidCallback onPressed,
    required bool large,
    bool isActive = false,
    // bool strikethrough = false,
  }) {
    final button = TranslucentIconButton(
      icon: icon,
      semanticLabel: semanticLabel,
      isActive: isActive,
      // strikethrough: strikethrough,
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
        Text(label, style: _labelStyle(context)),
      ],
    );
  }

  List<Widget> _mainButtons(
    BuildContext context,
    CameraViewModel viewModel, {
    required bool large,
  }) {
    final isFrozen = viewModel.isFrozen;
    return [
      _labeledButton(
        context,
        icon: Icons.cameraswitch_outlined,
        semanticLabel: 'Swap camera',
        label: 'SWAP',
        large: large,
        onPressed: viewModel.switchLens,
      ),
      _labeledButton(
        context,
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
        context,
        icon: Icons.camera_alt_outlined,
        semanticLabel: 'Snapshot',
        label: 'SNAP',
        large: large,
        onPressed: widget.onSnapshot,
      ),
      _labeledButton(
        context,
        // Material Icons has no dedicated "cancelled snowflake" glyph,
        // so the resumed state reuses the same snowflake with a
        // strike bar drawn over it (see TranslucentIconButton) rather
        // than switching to an unrelated icon - it reads as "freeze,
        // cancelled" instead of an arbitrary play/pause swap.
        icon: Icons.ac_unit,
        // strikethrough: isFrozen,
        semanticLabel: isFrozen ? 'Resume' : 'Freeze',
        label: isFrozen ? 'RESUME' : 'FREEZE',
        isActive: isFrozen,
        large: large,
        onPressed: viewModel.toggleFreeze,
      ),
    ];
  }

  /// Lays the 4 main buttons out as a 2x2 grid (rather than a single
  /// line of 4), so each button gets more breathing room in both
  /// dimensions regardless of the sector's own aspect ratio.
  Widget _buttonGrid(List<Widget> buttons, {required bool large}) {
    final gap = large ? 16.0 : 12.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buttons[0],
            SizedBox(width: gap),
            buttons[1],
          ],
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buttons[2],
            SizedBox(width: gap),
            buttons[3],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // This sector's own box, not the device orientation - it
              // stays consistent with how the rest of the app sizes
              // itself off available constraints rather than raw
              // screen/hardware queries.
              final isVertical = constraints.maxHeight > constraints.maxWidth;
              final buttons = _mainButtons(
                context,
                viewModel,
                large: isVertical,
              );
              final grid = _buttonGrid(buttons, large: isVertical);
              final colorStrip = _AverageColorStrip(
                color: widget.averageColor,
                vertical: isVertical,
              );

              // The strip is a sibling of the button grid (not stacked
              // on top of it) so the two can never visually overlap: in
              // the vertical layout it's a fixed-height band across the
              // full width at the top, with the grid positioned 16% up
              // from center in the remaining space below; in the
              // horizontal layout it's a fixed-width band across the full
              // height on the left, with the grid positioned 16% left
              // from center in the remaining space to the right.
              if (isVertical) {
                return Column(
                  children: [
                    colorStrip,
                    Expanded(
                      child: Align(
                        alignment: const Alignment(0, -0.4),
                        child: grid,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  colorStrip,
                  Expanded(
                    child: Align(
                      alignment: const Alignment(-0.4, 0),
                      child: grid,
                    ),
                  ),
                ],
              );
            },
          ),
          // "Keep screen on" sits bottom-left, the full width of the
          // sector away from the Settings button, so the two never read
          // as a single cluster of navigation chrome.
          Positioned(
            left: 8,
            bottom: 8,
            child: _keepScreenOnControl(),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: TranslucentIconButton(
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
          ),
        ],
      ),
    );
  }
}

/// The average-color readout: a full-bleed strip (no rounded corners,
/// spanning the sector's full width in the vertical layout or full
/// height in the horizontal one, so it reads as a continuation of the
/// sector rather than a separate floating card) filled with the
/// currently detected mean color, with its RGB/CMYK/LAB values printed
/// on top in a text color chosen for contrast against that fill.
class _AverageColorStrip extends StatelessWidget {
  const _AverageColorStrip({required this.color, required this.vertical});

  final RgbColor? color;

  /// True when this strip spans the sector's full width (sitting above
  /// the button grid); false when it spans the full height (sitting to
  /// the grid's left).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final sampled = color;
    final colorScheme = Theme.of(context).colorScheme;
    final child = sampled == null
        ? Text(
            'Detecting color…',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 9,
            ),
          )
        : _readout(sampled);

    return Container(
      width: vertical ? double.infinity : _averageColorStripThickness,
      height: vertical ? _averageColorStripThickness : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      alignment: Alignment.centerLeft,
      // Once a color has actually been sampled, this fills with that
      // measured color verbatim - it's real data being displayed, not
      // chrome, so unlike the "detecting..." idle state above it never
      // changes with the theme.
      color: sampled == null
          ? colorScheme.onSurface.withValues(alpha: 0.08)
          : Color.fromARGB(255, sampled.r, sampled.g, sampled.b),
      child: child,
    );
  }

  Widget _readout(RgbColor sampled) {
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
      height: 1.35,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Avg. color:',
          style: textStyle.copyWith(fontWeight: FontWeight.w700),
        ),
        Text('RGB: ${sampled.hex}', style: textStyle),
        Text(
          'CMYK: ${cmyk.c}/${cmyk.m}/${cmyk.y}/${cmyk.k}',
          style: textStyle,
        ),
        Text('LAB: ${lab.l},${lab.a},${lab.b}', style: textStyle),
      ],
    );
  }
}
