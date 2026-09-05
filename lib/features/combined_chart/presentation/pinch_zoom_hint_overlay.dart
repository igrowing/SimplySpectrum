import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A minimal, self-dismissing "Pinch to zoom" hint drawn over the
/// chart half of the screen when the app starts.
///
/// The chart itself stays fully visible - no dimming, no card. For two
/// seconds, two greyish fingertip circles diverge and converge (twice),
/// with a "Pinch to zoom" caption; then the hint fades out and reports
/// [onFinished] so the host can drop it from the tree. The overlay is
/// wrapped in [IgnorePointer], so it never blocks the gestures it
/// advertises.
class PinchZoomHintOverlay extends StatefulWidget {
  const PinchZoomHintOverlay({required this.onFinished, super.key});

  /// Called once the animation completes; the host should remove the
  /// overlay from the tree.
  final VoidCallback onFinished;

  /// Total time the hint stays on screen.
  static const Duration displayDuration = Duration(seconds: 2);

  /// How many diverge/converge cycles the circles run through.
  static const int cycles = 2;

  @override
  State<PinchZoomHintOverlay> createState() => _PinchZoomHintOverlayState();
}

class _PinchZoomHintOverlayState extends State<PinchZoomHintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: PinchZoomHintOverlay.displayDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && !_finished) {
            _finished = true;
            widget.onFinished();
          }
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          // Fade out over the last 15% of the timeline.
          final opacity =
              1 - const Interval(0.85, 1).transform(t).clamp(0.0, 1.0);

          // Separation phase: two full diverge/converge cycles across
          // the whole timeline. sin(pi * phase) eases 0 -> 1 -> 0 once
          // per cycle, so the circles glide out and back instead of
          // snapping.
          final phase = (t * PinchZoomHintOverlay.cycles) % 1;
          final closeness = math.sin(math.pi * phase);
          // 14px apart (almost touching) out to 90px apart.
          final separation = 14.0 + 76.0 * closeness;

          return Center(
            child: Opacity(
              opacity: opacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 70 - separation / 2 - 12,
                          child: _fingerDot(),
                        ),
                        Positioned(
                          right: 70 - separation / 2 - 12,
                          child: _fingerDot(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pinch to zoom',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// One greyish fingertip circle. A white rim keeps it readable over
  /// both the light and the dark chart theme.
  Widget _fingerDot() => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: const Color(0xFF9E9E9E).withValues(alpha: 0.85),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 4,
        ),
      ],
    ),
  );
}
