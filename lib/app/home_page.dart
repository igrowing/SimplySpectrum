import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simply_spectrum/core/di/injection.dart';
import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_sector_widget.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/frame_analysis/presentation/analysis_view_model.dart';
import 'package:simply_spectrum/features/luminosity_analysis/presentation/luminosity_sector_widget.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/presentation/controls_sector_widget.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';
import 'package:simply_spectrum/features/snapshot/domain/snapshot_repository.dart';
import 'package:simply_spectrum/features/spectrum_analysis/presentation/spectrum_sector_widget.dart';

/// The app shell: a 2x2 grid of "sectors" - Camera, Color chart,
/// Luminosity chart and Controls - sized responsively with
/// [LayoutBuilder] rather than querying raw screen dimensions or
/// hardware type, per project rules. Which sector occupies which
/// quadrant is user-configurable (see the Settings screen's "Main
/// screen order" section and `AppSettings.sectorAt`), defaulting to
/// the grid's original fixed arrangement.
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
      await sl<SnapshotRepository>().captureAndSave(_screenBoundaryKey);
      messenger.showSnackBar(
        const SnackBar(content: Text('Snapshot saved to gallery')),
      );
    } on SnapshotFailure catch (error) {
      sl<AppLogger>().warning('Snapshot failed: ${error.message}');
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Builds whichever sector widget is currently assigned to [type] -
  /// see the Settings screen's "Main screen order" section and
  /// `AppSettings.sectorAt` - wiring it up to the same view models
  /// regardless of which physical quadrant it ends up in.
  Widget _buildSector(
    SectorWidgetType type, {
    required BuildContext context,
    required CameraViewModel camera,
    required AppSettings settings,
    required AnalysisViewModel analysis,
  }) {
    switch (type) {
      case SectorWidgetType.camera:
        return CameraSectorWidget(
          viewModel: camera,
          brightestPoint: analysis.brightestPoint,
          darkestPoint: analysis.darkestPoint,
          showExtremeLightSpots: settings.showExtremeLightSpots,
          enhanceColors: settings.enhanceColors,
        );
      case SectorWidgetType.colorChart:
        return SpectrumSectorWidget(
          histogram: analysis.spectrum,
          unit: settings.spectrumUnit,
          showPeaks: settings.detectColorPeaks,
          yAxisMax: analysis.spectrumAxisMax,
        );
      case SectorWidgetType.luminosityChart:
        return LuminositySectorWidget(
          histogram: analysis.luminosity,
          yAxisMax: analysis.luminosityAxisMax,
        );
      case SectorWidgetType.controls:
        return ControlsSectorWidget(
          viewModel: camera,
          onSnapshot: () => _handleSnapshot(context),
          averageColor: analysis.averageColor,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background color intentionally left unset so it follows the
      // theme's scaffoldBackgroundColor (see main.dart) - the sector
      // grid's chrome (backgrounds, chart grids/labels, button/text
      // colors) now properly inverts with the light/dark/system theme
      // setting. Only the live camera texture itself (CameraPreview,
      // the optional color-enhance filter, and the brightest/darkest
      // point markers/overlay drawn on it) stays fixed regardless of
      // theme - see CameraSectorWidget.
      //
      // A global SafeArea is also applied in MaterialApp's `builder`
      // (see main.dart) so pushed routes (Settings, the info screens)
      // get the same treatment. This screen additionally wraps its own
      // body explicitly: it's the one laid out edge-to-edge as a 2x2
      // sector grid sized directly off the incoming constraints, so
      // it's the one place a gap in safe-area propagation would be
      // most visible - the bottom sectors drawn under the Android
      // navigation bar.
      body: SafeArea(
        child: RepaintBoundary(
          key: _screenBoundaryKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sectorWidth = constraints.maxWidth / 2;
              final sectorHeight = constraints.maxHeight / 2;

              return Consumer3<
                CameraViewModel,
                SettingsViewModel,
                AnalysisViewModel
              >(
                builder: (context, camera, settingsViewModel, analysis, _) {
                  final settings = settingsViewModel.settings;
                  analysis.settings = settings;
                  Widget sectorAt(SectorPosition position) {
                    return _buildSector(
                      settings.sectorAt(position),
                      context: context,
                      camera: camera,
                      settings: settings,
                      analysis: analysis,
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: sectorWidth,
                            height: sectorHeight,
                            child: sectorAt(SectorPosition.topLeft),
                          ),
                          SizedBox(
                            width: sectorWidth,
                            height: sectorHeight,
                            child: sectorAt(SectorPosition.topRight),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: sectorWidth,
                            height: sectorHeight,
                            child: sectorAt(SectorPosition.bottomLeft),
                          ),
                          SizedBox(
                            width: sectorWidth,
                            height: sectorHeight,
                            child: sectorAt(SectorPosition.bottomRight),
                          ),
                        ],
                      ),
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
