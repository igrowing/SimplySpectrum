import 'package:flutter/material.dart';

/// Full-screen explanation of luminosity and how to read the Luminosity
/// sector's chart. Reachable via the sector's info button.
class LuminosityInfoScreen extends StatelessWidget {
  const LuminosityInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About the Luminosity chart'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Paragraph(
                'Luminosity here means how bright each part of the picture '
                'is, from pure black to pure white, ignoring color.',
              ),
              _Paragraph(
                'The white line is a histogram: its height at each point '
                'along the X axis shows how many sampled pixels in the '
                'current frame have that brightness level.',
              ),
              _Paragraph(
                'The gradient bar under the chart runs from black (left) '
                'to white (right), matching the brightness scale of the X '
                'axis, so you can see at a glance whether the scene is '
                'mostly dark or mostly bright.',
              ),
              _Paragraph(
                '"Average luminosity" at the top is the '
                'occurrence-weighted average brightness across the frame - '
                'brightness levels seen in more pixels count more toward '
                'the average.',
              ),
              _Paragraph(
                'Note: this is an uncalibrated, camera-relative brightness '
                'estimate shown in lux for convenience, not a certified '
                'photometric measurement from a calibrated light meter.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.75),
          height: 1.4,
        ),
      ),
    );
  }
}
