import 'package:flutter/material.dart';

/// The small half-transparent circular icon button used for camera
/// controls (swap/light/snapshot/freeze), the Controls sector's smaller
/// toggles, and the sector "info" buttons, matching the familiar
/// overlay-button look of most camera apps.
class TranslucentIconButton extends StatelessWidget {
  const TranslucentIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.isActive = false,
    this.iconSize = 22,
    this.padding = const EdgeInsets.all(10),
    // this.strikethrough = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  /// When true, renders with a brighter background to indicate an "on"
  /// state (e.g. torch enabled).
  final bool isActive;

  /// Icon glyph size. Defaults to the "large" size used for the primary
  /// camera controls; pass a smaller value for secondary toggles.
  final double iconSize;

  /// Padding around the icon, shrinking the tappable circle to match a
  /// smaller [iconSize] when needed.
  final EdgeInsetsGeometry padding;

  /// Draws a diagonal bar over [icon], for glyphs (like the snowflake
  /// used for "freeze") that have no dedicated "off"/cancelled variant
  /// in Material Icons - visually the same "cancelled" language as
  /// icons that do (e.g. flash_off's built-in slash).
  // final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.black : Colors.white;
    return Material(
      color: (isActive ? Colors.white : Colors.black).withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: padding,
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: iconSize,
                  semanticLabel: semanticLabel,
                ),
                // if (strikethrough)
                //   Transform.rotate(
                //     key: const Key('translucentIconButton_strikethrough'),
                //     angle: -0.785398, // -45 degrees, in radians.
                //     child: Container(
                //       width: iconSize * 1.15,
                //       height: (iconSize * 0.12).clamp(1.5, 4),
                //       decoration: BoxDecoration(
                //         color: color,
                //         borderRadius: BorderRadius.circular(2),
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
