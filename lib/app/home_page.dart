import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simply_spectrum/core/di/injection.dart';
import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_sector_widget.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/frame_analysis/presentation/analysis_view_model.dart';
import 'package:simply_spectrum/features/luminosity_analysis/presentation/luminosity_sector_widget.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_sector_widget.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';
import 'package:simply_spectrum/features/snapshot/domain/snapshot_repository.dart';
import 'package:simply_spectrum/features/spectrum_analysis/presentation/spectrum_sector_widget.dart';

/// The app shell: a 2x2 grid of "sectors" - Camera, Spectrum, Luminosity
/// and Settings - sized responsively with [LayoutBuilder] rather than
/// querying raw screen dimensions or hardware type, per project rules.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                builder: (context, camera, settings, analysis, _) {
                  analysis.settings = settings.settings;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: sectorWidth,
                            height: sectorHeight,
                            child: CameraSectorWidget(
                              viewModel: camera,
                              onSnapshot: () => _handleSnapshot(context),
                              brightestPoint: analysis.brightestPoint,
                              darkestPoint: analysis.darkestPoint,
                              showBrightestPoint:
                                  settings.settings.showBrightestPoint,
                              showDarkestPoint:
                                  settings.settings.showDarkestPoint,
                            ),
                          ),
                          SizedBox(
                            width: sectorWidth,
                            height: sectorHeight,
                            child: SpectrumSectorWidget(
                              histogram: analysis.spectrum,
                              unit: settings.settings.spectrumUnit,
                              showPeaks: settings.settings.detectColorPeaks,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: sectorWidth,
                            height: sectorHeight,
                            child: LuminositySectorWidget(
                              histogram: analysis.luminosity,
                            ),
                          ),
                          SizedBox(
                            width: sectorWidth,
                            height: sectorHeight,
                            child: const SettingsSectorWidget(),
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
