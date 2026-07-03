import 'dart:async';

import 'package:flutter/material.dart';

import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';
import 'package:simply_spectrum/features/luminosity_analysis/domain/luminosity_histogram.dart';
import 'package:simply_spectrum/features/luminosity_analysis/presentation/luminosity_chart_painter.dart';
import 'package:simply_spectrum/features/luminosity_analysis/presentation/luminosity_info_screen.dart';

/// The Luminosity sector: live brightness-occurrence chart plus its title
/// and info button.
class LuminositySectorWidget extends StatelessWidget {
  const LuminositySectorWidget({required this.histogram, super.key});

  final LuminosityHistogram histogram;

  String _averageLabel() {
    final avgLux = histogram.weightedAverageApproxLux;
    if (avgLux == null) return 'Average luminosity: -';
    return 'Average luminosity: ${avgLux.round()} lux';
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
                    painter: LuminosityChartPainter(histogram: histogram),
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
              semanticLabel: 'Luminosity info',
              onPressed: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LuminosityInfoScreen(),
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
