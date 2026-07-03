import 'package:flutter/material.dart';

/// The small half-transparent circular icon button used for camera
/// controls (swap/light/snapshot) and the sector "info" buttons, matching
/// the familiar overlay-button look of most camera apps.
class TranslucentIconButton extends StatelessWidget {
  const TranslucentIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  /// When true, renders with a brighter background to indicate an "on"
  /// state (e.g. torch enabled).
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: (isActive ? Colors.white : Colors.black).withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: isActive ? Colors.black : Colors.white,
            size: 22,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}
