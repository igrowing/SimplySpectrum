import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simply_spectrum/core/di/injection.dart';
import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_sector_widget.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/analysis_chart_widget.dart';
import 'package:simply_spectrum/features/frame_analysis/presentation/analysis_view_model.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/presentation/controls_sector_widget.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';
import 'package:simply_spectrum/features/snapshot/domain/snapshot_repository.dart';

/// The app shell: the combined analysis chart (spectrum + luminosity)
/// and, in the other half of the screen, the camera preview stacked
/// above the Controls sector.
///
/// In the vertical layout the chart takes the full screen width in
/// the upper half (or lower half - see the "Charts placement" setting,
/// [AppSettings.chartsAtTop]) and camera + controls share the other
/// half, stacked. In the horizontal layout the chart takes the left
/// half (or right half, same setting) and camera + controls share the
/// other half. Sizing is purely constraint-driven ([LayoutBuilder]),
/// per project rules - the "vertical/horizontal" choice follows the
/// incoming box's own aspect ratio, not raw screen queries.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _screenBoundaryKey = GlobalKey();

  Future<void> _handleSnapshot(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final savedTo = await sl<SnapshotRepository>().captureAndSave(
        _screenBoundaryKey,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Snapshot saved to $savedTo')),
      );
    } on SnapshotFailure catch (error) {
      sl<AppLogger>().warning('Snapshot failed: ${error.message}');
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// The camera + controls half: the live preview on top (it needs the
  /// bigger share of the space) and the Controls sector (average-color
  /// strip + button grid + corner toggles) below it. Both layouts
  /// (the bottom half in vertical, the right half in horizontal) stack
  /// these two vertically, since both regions are taller than wide or
  /// short-and-wide respectively - the controls widget adapts its own
  /// internal arrangement to its box independently.
  Widget _buildCameraAndControls({
    required CameraViewModel camera,
    required AppSettings settings,
    required AnalysisViewModel analysis,
    required VoidCallback onSnapshot,
  }) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: CameraSectorWidget(
            viewModel: camera,
            brightestPoint: analysis.brightestPoint,
            darkestPoint: analysis.darkestPoint,
            showExtremeLightSpots: settings.showExtremeLightSpots,
            enhanceColors: settings.enhanceColors,
          ),
        ),
        Expanded(
          flex: 2,
          child: ControlsSectorWidget(
            viewModel: camera,
            onSnapshot: onSnapshot,
            averageColor: analysis.averageColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCharts({
    required AppSettings settings,
    required AnalysisViewModel analysis,
  }) {
    return AnalysisChartWidget(
      spectrum: analysis.spectrum,
      luminosity: analysis.luminosity,
      unit: settings.spectrumUnit,
      showPeaks: settings.detectColorPeaks,
      spectrumYAxisMax: analysis.spectrumAxisMax,
      luminosityYAxisMax: analysis.luminosityAxisMax,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background color intentionally left unset so it follows the
      // theme's scaffoldBackgroundColor (see main.dart) - the app's
      // chrome (backgrounds, chart grids/labels, button/text colors)
      // inverts with the light/dark/system theme setting. Only the
      // live camera texture itself (and the markers drawn on it) stays
      // fixed regardless of theme - see CameraSectorWidget.
      //
      // A global SafeArea is also applied in MaterialApp's `builder`
      // (see main.dart) so pushed routes (Settings, the info screens)
      // get the same treatment. This screen additionally wraps its own
      // body explicitly: it's the one laid out edge-to-edge as a
      // half/half grid sized directly off the incoming constraints, so
      // it's the one place a gap in safe-area propagation would be most
      // visible - content drawn under the Android navigation bar.
      body: SafeArea(
        child: RepaintBoundary(
          key: _screenBoundaryKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // This layout's own box, not the device orientation - it
              // stays consistent with how the rest of the app sizes
              // itself off available constraints rather than raw
              // screen/hardware queries.
              final isVertical = constraints.maxHeight > constraints.maxWidth;

              return Consumer3<
                CameraViewModel,
                SettingsViewModel,
                AnalysisViewModel
              >(
                builder: (context, camera, settingsViewModel, analysis, _) {
                  final settings = settingsViewModel.settings;
                  analysis.settings = settings;

                  final charts = _buildCharts(
                    settings: settings,
                    analysis: analysis,
                  );
                  final cameraAndControls = _buildCameraAndControls(
                    camera: camera,
                    settings: settings,
                    analysis: analysis,
                    onSnapshot: () => _handleSnapshot(context),
                  );

                  // "Charts placement" setting: charts on top (or on
                  // the left, in horizontal) vs bottom/right.
                  final chartsFirst = settings.chartsAtTop;

                  if (isVertical) {
                    return Column(
                      children: [
                        Expanded(
                          child: chartsFirst ? charts : cameraAndControls,
                        ),
                        Expanded(
                          child: chartsFirst ? cameraAndControls : charts,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: chartsFirst ? charts : cameraAndControls,
                      ),
                      Expanded(child: chartsFirst ? cameraAndControls : charts),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
