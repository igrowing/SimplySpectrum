import 'dart:async';

import 'package:flutter/material.dart';

import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/spectrum_analysis/domain/spectrum_histogram.dart';
import 'package:simply_spectrum/features/spectrum_analysis/presentation/spectrum_chart_painter.dart';
import 'package:simply_spectrum/features/spectrum_analysis/presentation/spectrum_info_screen.dart';

/// The Spectrum sector: live wavelength-occurrence chart plus its title
/// and info button.
class SpectrumSectorWidget extends StatelessWidget {
  const SpectrumSectorWidget({
    required this.histogram,
    required this.unit,
    required this.showPeaks,
    required this.yAxisMax,
    super.key,
  });

  final SpectrumHistogram histogram;
  final SpectrumUnit unit;
  final bool showPeaks;
  final int yAxisMax;

  String _averageLabel() {
    final avgNm = histogram.weightedAverageNm;
    if (avgNm == null) return 'Average color: -';
    if (unit == SpectrumUnit.wavelengthNm) {
      return 'Average color: ${avgNm.round()} nm';
    }
    final hz = nmToHz(avgNm);
    return 'Average color: ${(hz / 1e14).toStringAsFixed(2)}e14 Hz';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 44, 4),
                child: Text(
                  _averageLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: CustomPaint(
                    painter: SpectrumChartPainter(
                      histogram: histogram,
                      unit: unit,
                      showPeaks: showPeaks,
                      yAxisMax: yAxisMax,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 6,
            right: 6,
            child: TranslucentIconButton(
              icon: Icons.info_outline,
              semanticLabel: 'Spectrum info',
              onPressed: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SpectrumInfoScreen(),
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
