import 'package:flutter/material.dart';

/// Full-screen explanation of the visible spectrum and how to read the
/// Spectrum sector's chart. Reachable via the sector's info button.
class SpectrumInfoScreen extends StatelessWidget {
  const SpectrumInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101014),
        title: const Text('About the Spectrum chart'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Paragraph(
                'The visible spectrum is the range of light wavelengths '
                'humans can see, roughly 400-700 nanometers (nm). Violet '
                'sits at the short end (~400nm), red at the long end '
                '(~700nm), with blue, green, yellow and orange in between.',
              ),
              _Paragraph(
                'This chart samples pixels from the live camera picture '
                'and estimates the closest visible wavelength for each '
                'colorful (non-grey) pixel. The white line is a histogram: '
                'its height at each point on the X axis shows how often '
                'that wavelength appeared in the current frame.',
              ),
              _Paragraph(
                'The colored bar under the chart is a static reference of '
                'the visible spectrum from 400nm to 700nm, with tick marks '
                'every 100nm, so you can line up a peak in the chart with '
                'the color it represents.',
              ),
              _Paragraph(
                '"Average color" at the top is the occurrence-weighted '
                'average wavelength across the frame - wavelengths seen in '
                'more pixels count more toward the average.',
              ),
              _Paragraph(
                'Note: a phone camera does not contain a spectrometer. '
                'This estimates the closest matching monochromatic color '
                'for what the sensor sees - it is a useful approximation, '
                'not a lab-grade spectral measurement.',
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
        style: const TextStyle(color: Colors.white70, height: 1.4),
      ),
    );
  }
}
