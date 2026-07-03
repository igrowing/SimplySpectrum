import 'package:flutter/material.dart';

/// The small half-transparent circular icon button used for camera
/// controls (swap/light/snapshot), the Controls sector's smaller toggles,
/// and the sector "info" buttons, matching the familiar overlay-button
/// look of most camera apps.
class TranslucentIconButton extends StatelessWidget {
  const TranslucentIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.isActive = false,
    this.iconSize = 22,
    this.padding = const EdgeInsets.all(10),
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: (isActive ? Colors.white : Colors.black).withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: padding,
          child: Icon(
            icon,
            color: isActive ? Colors.black : Colors.white,
            size: iconSize,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}
