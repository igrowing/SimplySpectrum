import 'package:flutter/material.dart';

/// Full-screen explanation of the combined chart: how to read the
/// spectrum and luminosity lines drawn over the shared plot. Reachable
/// via the chart's single info button.
class CombinedChartInfoScreen extends StatelessWidget {
  const CombinedChartInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About the chart'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Paragraph(
                'This chart overlays two live histograms from the camera '
                'picture on one shared plot. The colored line is the '
                'spectrum: it samples the picture and estimates the '
                'closest visible wavelength for each colorful (non-grey) '
                'pixel, then counts how often each wavelength appears. '
                'The line is painted segment-by-segment in the wavelength\'s '
                'own color - violet around 400nm on the left through red '
                'around 700nm on the right (or the equivalent in '
                'frequency/THz), so the color coding reads at a glance.',
              ),
              _Paragraph(
                'The plain contrast line is the luminosity: how bright the '
                'picture is from pure black to pure white, ignoring '
                'color. Its height shows how many sampled pixels have each '
                'brightness level, and its horizontal position matches the '
                'black-to-white gradient bar at the bottom of the chart - '
                'black (dark) on the left, white (bright) on the right, so '
                'you can see at a glance whether the scene is mostly dark '
                'or mostly bright.',
              ),
              _Paragraph(
                'The left axis ("px") counts how often each value appeared '
                'in the sampled pixels; both lines scale against it. The '
                'two "Avg" readouts at the top are the occurrence-weighted '
                'average wavelength and the approximate brightness in lux - '
                'values seen in more pixels count more toward the '
                'averages.',
              ),
              _Paragraph(
                'Pinch to zoom the chart (up to 12x), drag to pan while '
                'zoomed, and double-tap to reset to the full view. Grid '
                'lines and tick labels adapt to the zoomed window, so '
                'zooming in reveals finer detail instead of just '
                'magnifying.',
              ),
              _Paragraph(
                'Note: a phone camera does not contain a spectrometer or a '
                'calibrated light meter. The spectrum line estimates the '
                'closest matching monochromatic color for what the sensor '
                'sees, and the lux figure is an uncalibrated, '
                'camera-relative brightness estimate shown for '
                'convenience - useful approximations, not lab-grade '
                'measurements.',
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
          color: Theme.of(context).colorScheme.onSurface.withValues(
            alpha: 0.75,
          ),
          height: 1.4,
        ),
      ),
    );
  }
}
