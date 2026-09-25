import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/screen_wake_view_model.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/color_conversions.dart';
import 'package:simply_spectrum/features/frame_analysis/domain/rgb_color.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_screen.dart';

/// The "thickness" of the average-color strip: its height when it spans
/// the sector's full width (vertical layout), or its width when it spans
/// the sector's full height (horizontal layout).
const double _averageColorStripThickness = 120;

/// How far the 2x2 button grid shifts (in pixels) away from the "Keep
/// screen on" + Settings corner cluster in the horizontal layout - see
/// [ControlsSectorWidget._buildHorizontal].
const double _horizontalGridShift = 40;

/// The Controls sector: the average-color readout (a full-bleed strip
/// that reads as a continuation of the sector rather than a floating
/// card) plus a 2x2 grid of camera controls (swap lens, torch, snapshot,
/// freeze) and the "Keep screen on" / Settings controls. Detailed
/// settings switches live on their own full [SettingsScreen] instead,
/// keeping this sector uncluttered.
///
/// Stateless: the "Keep screen on" toggle itself lives in
/// [ScreenWakeViewModel] (an app-root view model, read here via
/// `provider`) rather than local State, so it survives this widget's
/// own subtree being torn down and rebuilt - which a device rotation
/// (swapping the horizontal/vertical layout) or the "Charts placement"
/// setting (reordering which half of the screen this sits in) both do.
class ControlsSectorWidget extends StatelessWidget {
  const ControlsSectorWidget({
    required this.viewModel,
    required this.onSnapshot,
    super.key,
    this.averageColor,
    this.mirrored = false,
  });

  final CameraViewModel viewModel;
  final VoidCallback onSnapshot;

  /// Mean color of the most recently analyzed frame (null before the
  /// first frame is analyzed), rendered as the RGB/CMYK/LAB readout
  /// strip.
  final RgbColor? averageColor;

  /// Only meaningful when this sector's own box is short and wide (the
  /// horizontal layout's camera+controls half sits on the *left*, i.e.
  /// the "Charts placement" setting has the charts on the right):
  /// swaps which side the average-color band and the button grid sit
  /// on, so the band stays next to the charts (screen center) and the
  /// buttons stay next to the screen's outer edge - a true left/right
  /// mirror of the default (charts-on-the-left) arrangement. Ignored
  /// when this sector's box is tall and narrow (the vertical layout).
  /// Default: false.
  final bool mirrored;

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

  Future<void> _toggleKeepScreenOn(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final screenWake = context.read<ScreenWakeViewModel>();
    await screenWake.toggle();
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            screenWake.keepScreenOn
                ? 'Keeping the screen on'
                : 'Screen will turn off by system timeout',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// The "keep screen on" toggle: a labelled translucent pill (lightbulb
  /// icon + word). A filled bulb + brighter fill = on; an outline bulb =
  /// off. Long-press (and screen readers) surface the fuller "Keep
  /// screen on" phrasing.
  Widget _keepScreenOnControl(BuildContext context, {required bool active}) {
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
            onTap: () => unawaited(_toggleKeepScreenOn(context)),
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

  /// The Settings gear.
  Widget _settingsButton(BuildContext context) {
    return TranslucentIconButton(
      icon: Icons.settings_outlined,
      semanticLabel: 'Settings',
      iconSize: 16,
      padding: const EdgeInsets.all(7),
      onPressed: () {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        );
      },
    );
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
        onPressed: onSnapshot,
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

  /// The button grid plus the "Keep screen on" and Settings corner
  /// controls, as a self-contained pane: the corners are anchored to
  /// *this pane's own* box, not the wider sector - in the horizontal
  /// layout this pane sits beside the average-color strip (see
  /// [_buildHorizontal]) rather than spanning the sector's full width,
  /// so anchoring the corner controls here (instead of the whole
  /// sector) keeps them off the strip regardless of which side it's on.
  ///
  /// [clusterOnRight] is null in the vertical layout (see
  /// [_buildVertical]): the strip there is full-width at the top, so
  /// the pane's whole width is free and the two corner controls simply
  /// sit at its opposite bottom corners. In the horizontal layout the
  /// pane is narrow, so both corner controls stack vertically instead -
  /// "Keep screen on" above Settings - at whichever side
  /// [clusterOnRight] names, which is always this pane's *outer* edge
  /// (away from the strip); [gridShiftX] then nudges the grid the rest
  /// of the way clear of that stack.
  Widget _buttonPane({
    required Widget grid,
    required Alignment gridAlignment,
    required Widget screenOnControl,
    required Widget settingsButton,
    double gridShiftX = 0,
    bool? clusterOnRight,
  }) {
    final gridWidget = Align(
      alignment: gridAlignment,
      child: gridShiftX == 0
          ? grid
          : Transform.translate(offset: Offset(gridShiftX, 0), child: grid),
    );

    if (clusterOnRight == null) {
      return Stack(
        children: [
          gridWidget,
          Positioned(left: 8, bottom: 8, child: screenOnControl),
          Positioned(right: 8, bottom: 8, child: settingsButton),
        ],
      );
    }
    return Stack(
      children: [
        gridWidget,
        Positioned(
          top: 8,
          right: clusterOnRight ? 8 : null,
          left: clusterOnRight ? null : 8,
          child: screenOnControl,
        ),
        Positioned(
          bottom: 8,
          right: clusterOnRight ? 8 : null,
          left: clusterOnRight ? null : 8,
          child: settingsButton,
        ),
      ],
    );
  }

  Widget _buildVertical(
    Widget grid,
    Widget colorStrip,
    Widget screenOnControl,
    Widget settingsButton,
  ) {
    // Fixed-height band across the full width at the top; the button
    // pane (grid + corner controls) fills the remaining space below,
    // with the grid nudged 16% up from that pane's center to clear the
    // corner controls at its bottom.
    return Column(
      children: [
        colorStrip,
        Expanded(
          child: _buttonPane(
            grid: grid,
            gridAlignment: const Alignment(0, -0.4),
            screenOnControl: screenOnControl,
            settingsButton: settingsButton,
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontal(
    Widget grid,
    Widget colorStrip,
    Widget screenOnControl,
    Widget settingsButton,
  ) {
    // Fixed-width band across the full height on one side; the button
    // pane fills the remaining space. "Keep screen on" and Settings
    // stack vertically at the pane's *outer* edge (away from the
    // strip/charts) instead of splitting to opposite bottom corners -
    // the horizontal span here is too narrow for that without the
    // "Keep screen on" pill covering the grid - and the grid itself
    // shifts further toward the strip to clear that stack. By default
    // the strip sits on the left with the pane (and its outer edge, on
    // the right) to its right; when [mirrored] is set the two swap
    // sides, so the cluster and grid-shift both flip too, keeping the
    // whole arrangement a true left/right mirror of the default.
    final clusterOnRight = !mirrored;
    final buttonPane = Expanded(
      child: _buttonPane(
        grid: grid,
        gridAlignment: Alignment.center,
        gridShiftX: clusterOnRight
            ? -_horizontalGridShift
            : _horizontalGridShift,
        screenOnControl: screenOnControl,
        settingsButton: settingsButton,
        clusterOnRight: clusterOnRight,
      ),
    );
    return Row(
      children: mirrored ? [buttonPane, colorStrip] : [colorStrip, buttonPane],
    );
  }

  @override
  Widget build(BuildContext context) {
    final keepScreenOn = context.watch<ScreenWakeViewModel>().keepScreenOn;
    final screenOnControl = _keepScreenOnControl(context, active: keepScreenOn);
    final settingsButton = _settingsButton(context);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // This sector's own box, not the device orientation - it
          // stays consistent with how the rest of the app sizes itself
          // off available constraints rather than raw screen/hardware
          // queries.
          final isVertical = constraints.maxHeight > constraints.maxWidth;
          final buttons = _mainButtons(context, viewModel, large: isVertical);
          final grid = _buttonGrid(buttons, large: isVertical);
          final colorStrip = _AverageColorStrip(
            color: averageColor,
            vertical: isVertical,
          );

          // The strip is a sibling of the button pane (not stacked on
          // top of it) so the two can never visually overlap.
          return isVertical
              ? _buildVertical(
                  grid,
                  colorStrip,
                  screenOnControl,
                  settingsButton,
                )
              : _buildHorizontal(
                  grid,
                  colorStrip,
                  screenOnControl,
                  settingsButton,
                );
        },
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
        Text('CMYK: ${cmyk.c}/${cmyk.m}/${cmyk.y}/${cmyk.k}', style: textStyle),
        Text('LAB: ${lab.l},${lab.a},${lab.b}', style: textStyle),
      ],
    );
  }
}
