import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:simply_spectrum/app/home_page.dart';
import 'package:simply_spectrum/core/di/injection.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/data/camera_repository_impl.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_repository.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/camera_view_model.dart';
import 'package:simply_spectrum/features/frame_analysis/presentation/analysis_view_model.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/domain/settings_repository.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Explicitly (rather than relying on whatever a given Android version/
  // OEM skin defaults to) request edge-to-edge: the app draws full-bleed
  // behind the status/navigation bars and Flutter reports their real
  // dimensions back through MediaQuery.padding, which SafeArea (see
  // below) then uses to keep content clear of them. Without this
  // explicit call, some devices - particularly with 3-button
  // navigation - have been seen to under-report the navigation bar
  // inset, letting the bottom row of sectors get drawn underneath it.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  setupInjection();
  runApp(const SimplySpectrumApp());
}

/// Root widget: wires up the long-lived view models via `provider` and
/// applies the user's chosen light/dark/system theme app-wide,
/// including the main sector grid's chrome (backgrounds, chart
/// grids/labels, button/text colors). The one deliberate exception is
/// the live camera texture itself - see CameraSectorWidget - which
/// always renders untouched by the theme.
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
      child: Consumer<SettingsViewModel>(
        builder: (_, settingsViewModel, _) {
          return MaterialApp(
            title: 'SimplySpectrum',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: _toThemeMode(settingsViewModel.settings.themeMode),
            // Applied globally (rather than per-screen) so every route -
            // including pushed info/settings screens - stays clear of
            // the Android status bar and, importantly, the
            // gesture/3-button navigation bar, which the OS otherwise
            // draws on top of the app's edge-to-edge content. See
            // igrowing/SimplyNet for the same pattern.
            builder: (_, child) =>
                SafeArea(child: child ?? const SizedBox.shrink()),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}

/// Maps the persisted, framework-agnostic [AppThemeMode] to Flutter's
/// own [ThemeMode] for [MaterialApp].
ThemeMode _toThemeMode(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}
