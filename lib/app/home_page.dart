import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simply_spectrum/core/di/injection.dart';
import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_sector_widget.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/analysis_chart_widget.dart';
import 'package:simply_spectrum/features/combined_chart/presentation/pinch_zoom_hint_overlay.dart';
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
/// other half, with camera always on top and controls always on the
/// bottom - only the Controls sector's own internal layout mirrors when
/// the chart is on the right, so that setting is a true left/right
/// mirror rather than a different composition. Sizing is purely
/// constraint-driven ([LayoutBuilder]),
/// per project rules - the "vertical/horizontal" choice follows the
/// incoming box's own aspect ratio, not raw screen queries.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _screenBoundaryKey = GlobalKey();

  /// Whether the one-shot pinch-to-zoom hint (shown over the chart
  /// half for the first two seconds after the app starts) is still
  /// on screen. Cleared by the overlay itself once its animation
  /// completes.
  bool _showPinchHint = true;

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

  /// The camera + controls half, arranged per orientation to keep each
  /// sector's pre-redesign shape: side by side in the vertical layout
  /// (camera left, controls right - the half is short and wide, so the
  /// sectors end up tall/narrow "vertical" ones) and stacked in the
  /// horizontal layout (camera above controls - the half is tall, so
  /// the sectors end up short/wide "horizontal" ones).
  ///
  /// The Camera sector is always on top and the Controls sector always
  /// on the bottom in the horizontal layout, regardless of which side
  /// the charts are on - only the Controls sector's *internal* layout
  /// mirrors (see [ControlsSectorWidget.mirrored]) so the "Charts
  /// placement: right" setting is a functional left/right mirror of the
  /// default rather than a different composition.
  Widget _buildCameraAndControls({
    required CameraViewModel camera,
    required AppSettings settings,
    required AnalysisViewModel analysis,
    required VoidCallback onSnapshot,
    required bool isVertical,
    required bool chartsFirst,
  }) {
    final cameraView = Expanded(
      flex: 3,
      child: CameraSectorWidget(
        viewModel: camera,
        brightestPoint: analysis.brightestPoint,
        darkestPoint: analysis.darkestPoint,
        showExtremeLightSpots: settings.showExtremeLightSpots,
        enhanceColors: settings.enhanceColors,
      ),
    );
    final controls = Expanded(
      flex: 2,
      child: ControlsSectorWidget(
        viewModel: camera,
        onSnapshot: onSnapshot,
        averageColor: analysis.averageColor,
        // Only meaningful once this half is on the *left* (charts on
        // the right) of the horizontal layout - the vertical layout
        // ignores it (see ControlsSectorWidget).
        mirrored: !isVertical && !chartsFirst,
      ),
    );

    if (isVertical) {
      return Row(children: [cameraView, controls]);
    }
    return Column(children: [cameraView, controls]);
  }

  Widget _buildCharts({
    required AppSettings settings,
    required AnalysisViewModel analysis,
  }) {
    final chart = AnalysisChartWidget(
      spectrum: analysis.spectrum,
      luminosity: analysis.luminosity,
      unit: settings.spectrumUnit,
      showPeaks: settings.detectColorPeaks,
      spectrumYAxisMax: analysis.spectrumAxisMax,
      luminosityYAxisMax: analysis.luminosityAxisMax,
    );

    // On app start, a two-second self-dismissing animation over the
    // chart advertises the pinch-to-zoom ability.
    if (!_showPinchHint) return chart;
    return Stack(
      children: [
        Positioned.fill(child: chart),
        Positioned.fill(
          child: PinchZoomHintOverlay(
            onFinished: () => setState(() => _showPinchHint = false),
          ),
        ),
      ],
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

                  // "Charts placement" setting: charts on top (or on
                  // the left, in horizontal) vs bottom/right.
                  final chartsFirst = settings.chartsAtTop;

                  final charts = _buildCharts(
                    settings: settings,
                    analysis: analysis,
                  );
                  final cameraAndControls = _buildCameraAndControls(
                    camera: camera,
                    settings: settings,
                    analysis: analysis,
                    onSnapshot: () => _handleSnapshot(context),
                    isVertical: isVertical,
                    chartsFirst: chartsFirst,
                  );

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
