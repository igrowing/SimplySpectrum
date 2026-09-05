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
        chartsAtTop: false,
      );

      await repository.save(settings);
      final reloaded = await repository.load();

      expect(reloaded, settings);
    });

    test('load() reads a persisted chartsAtTop=false', () async {
      SharedPreferences.setMockInitialValues({
        'settings.charts_at_top': false,
      });
      final repository = SettingsRepositoryImpl(
        logger: const DeveloperAppLogger(),
      );

      final settings = await repository.load();

      expect(settings.chartsAtTop, isFalse);
    });

    test('save() removes the retired legacy sector-layout keys', () async {
      SharedPreferences.setMockInitialValues({
        'settings.sector_top_left': 'camera',
        'settings.sector_bottom_right': 'controls',
      });
      final repository = SettingsRepositoryImpl(
        logger: const DeveloperAppLogger(),
      );

      await repository.save(const AppSettings());
      final stored = await SharedPreferences.getInstance();

      expect(stored.containsKey('settings.sector_top_left'), isFalse);
      expect(stored.containsKey('settings.sector_bottom_right'), isFalse);
      expect(stored.getBool('settings.charts_at_top'), isTrue);
    });

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
