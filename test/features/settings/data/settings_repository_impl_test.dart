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
      );

      await repository.save(settings);
      final reloaded = await repository.load();

      expect(reloaded, settings);
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
