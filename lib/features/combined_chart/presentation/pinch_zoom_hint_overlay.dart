import 'package:flutter/material.dart';

/// A short, self-dismissing "ability of pinch to zoom" hint shown over
/// the chart half of the screen when the app starts.
///
/// Plays a two-second animation - two fingertip dots pinching apart
/// over a mini chart line, with a text hint - then fades out and
/// reports [onFinished] so the host can drop it from the tree. The
/// overlay is wrapped in [IgnorePointer], so it never blocks the
/// gestures it advertises.
class PinchZoomHintOverlay extends StatefulWidget {
  const PinchZoomHintOverlay({required this.onFinished, super.key});

  /// Called once the hold + fade animation completes; the host should
  /// remove the overlay from the tree.
  final VoidCallback onFinished;

  /// Total time the hint stays on screen.
  static const Duration displayDuration = Duration(seconds: 2);

  @override
  State<PinchZoomHintOverlay> createState() => _PinchZoomHintOverlayState();
}

class _PinchZoomHintOverlayState extends State<PinchZoomHintOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _pinch;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    // Master timeline: hold the hint, then fade it out at the end.
    _master =
        AnimationController(
          vsync: this,
          duration: PinchZoomHintOverlay.displayDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && !_finished) {
            _finished = true;
            widget.onFinished();
          }
        });

    // Fingers pinch apart and back together, looping for the duration
    // of the hint so the gesture is unmistakable.
    _pinch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _master.forward();
  }

  @override
  void dispose() {
    _master.dispose();
    _pinch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _master,
        builder: (context, _) {
          // Opaque for the first 60% of the timeline, then ease out.
          final opacity =
              1 -
              const Interval(0.6, 1).transform(_master.value).clamp(0.0, 1.0);

          return ColoredBox(
            color: colorScheme.surface.withValues(alpha: 0.55 * opacity),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPinchDemo(colorScheme),
                      const SizedBox(height: 10),
                      Text(
                        'Pinch to zoom · Double-tap to reset',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The animated pinch demo: a mini chart snippet with two fingertip
  /// dots that move apart (zoom in) and back together.
  Widget _buildPinchDemo(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _pinch,
      builder: (context, _) {
        // Separation: 12px apart at t=0, 44px at t=1.
        final separation = 12.0 + 32.0 * _pinch.value;

        return SizedBox(
          width: 96,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A mini spectrum-ish line under the fingers, hinting at
              // what is being zoomed.
              CustomPaint(
                size: const Size(96, 44),
                painter: _MiniChartPainter(
                  color: colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
              Positioned(
                left: 48 - separation / 2 - 8,
                child: _fingerDot(colorScheme),
              ),
              Positioned(
                right: 48 - separation / 2 - 8,
                child: _fingerDot(colorScheme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fingerDot(ColorScheme colorScheme) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: colorScheme.primary,
      shape: BoxShape.circle,
      border: Border.all(color: colorScheme.surface, width: 2),
      boxShadow: [
        BoxShadow(
          color: colorScheme.onSurface.withValues(alpha: 0.3),
          blurRadius: 4,
        ),
      ],
    ),
  );
}

/// One smooth mini polyline with a peak, drawn in [color] - a tiny
/// stand-in for the spectrum chart the overlay advertises.
class _MiniChartPainter extends CustomPainter {
  _MiniChartPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.75,
      size.width * 0.45,
      size.height * 0.25,
    );
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.85,
      size.width * 0.8,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.45,
      size.width,
      size.height * 0.55,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MiniChartPainter oldDelegate) =>
      color != oldDelegate.color;
}
