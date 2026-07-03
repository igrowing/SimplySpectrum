import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simply_spectrum/app/home_page.dart';
import 'package:simply_spectrum/core/di/injection.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/data/camera_repository_impl.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_repository.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/frame_analysis/presentation/analysis_view_model.dart';
import 'package:simply_spectrum/features/settings/domain/settings_repository.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';

void main() {
  setupInjection();
  runApp(const SimplySpectrumApp());
}

/// Root widget: wires up the long-lived view models via `provider` and
/// applies the app-wide dark theme (the sectors are designed for a black
/// background with white/grey chart lines).
class SimplySpectrumApp extends StatelessWidget {
  const SimplySpectrumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CameraViewModel>(
          create: (_) => CameraViewModel(
            cameraRepository: sl<CameraRepositoryImpl>(),
            logger: sl<AppLogger>(),
          ),
        ),
        ChangeNotifierProvider<SettingsViewModel>(
          create: (_) => SettingsViewModel(
            repository: sl<SettingsRepository>(),
            logger: sl<AppLogger>(),
          ),
        ),
        ChangeNotifierProvider<AnalysisViewModel>(
          create: (_) =>
              AnalysisViewModel(cameraRepository: sl<CameraRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'SimplySpectrum',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomePage(),
      ),
    );
  }
}
