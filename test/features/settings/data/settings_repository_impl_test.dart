import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/settings/data/settings_repository_impl.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsRepositoryImpl', () {
    test('load() returns documented defaults on first launch', () async {
      final repository = SettingsRepositoryImpl(
        logger: const DeveloperAppLogger(),
      );

      final settings = await repository.load();

      expect(settings, const AppSettings());
    });

    test('save() then load() round-trips every field', () async {
      final repository = SettingsRepositoryImpl(
        logger: const DeveloperAppLogger(),
      );
      const settings = AppSettings(
        detectColorPeaks: false,
        spectrumUnit: SpectrumUnit.frequencyHz,
        showExtremeLightSpots: true,
        enhanceColors: true,
        topLeftSector: SectorWidgetType.controls,
        topRightSector: SectorWidgetType.luminosityChart,
        bottomLeftSector: SectorWidgetType.colorChart,
        bottomRightSector: SectorWidgetType.camera,
      );

      await repository.save(settings);
      final reloaded = await repository.load();

      expect(reloaded, settings);
    });

    test(
      'load() falls back to the default sector layout when the persisted '
      'layout is corrupt (e.g. a duplicated widget)',
      () async {
        SharedPreferences.setMockInitialValues({
          'settings.sector_top_left': SectorWidgetType.camera.name,
          'settings.sector_top_right': SectorWidgetType.camera.name,
          'settings.sector_bottom_left': SectorWidgetType.luminosityChart.name,
          'settings.sector_bottom_right': SectorWidgetType.controls.name,
        });
        final repository = SettingsRepositoryImpl(
          logger: const DeveloperAppLogger(),
        );

        final settings = await repository.load();

        const defaults = AppSettings();
        expect(settings.topLeftSector, defaults.topLeftSector);
        expect(settings.topRightSector, defaults.topRightSector);
        expect(settings.bottomLeftSector, defaults.bottomLeftSector);
        expect(settings.bottomRightSector, defaults.bottomRightSector);
      },
    );

    test(
      'load() falls back to the default theme when the persisted name is '
      'missing or unrecognized',
      () async {
        final repository = SettingsRepositoryImpl(
          logger: const DeveloperAppLogger(),
        );

        final settings = await repository.load();

        expect(settings.themeMode, AppThemeMode.system);
      },
    );

    test('load() migrates the legacy brightest/darkest point keys', () async {
      SharedPreferences.setMockInitialValues({
        'settings.show_brightest_point': true,
        'settings.show_darkest_point': false,
      });
      final repository = SettingsRepositoryImpl(
        logger: const DeveloperAppLogger(),
      );

      final settings = await repository.load();

      expect(settings.showExtremeLightSpots, isTrue);
    });
  });
}
