import 'package:shared_preferences/shared_preferences.dart';

import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/domain/settings_repository.dart';

const _kDetectColorPeaksKey = 'settings.detect_color_peaks';
const _kSpectrumUnitKey = 'settings.spectrum_unit_is_frequency';
const _kShowExtremeLightSpotsKey = 'settings.show_extreme_light_spots';
const _kEnhanceColorsKey = 'settings.enhance_colors';
const _kThemeModeKey = 'settings.theme_mode';
const _kChartsAtTopKey = 'settings.charts_at_top';

/// Legacy keys from the retired 2x2 sector-permutation layout (replaced
/// by the single "charts placement" toggle). Removed on save so stale
/// layout data never lingers in prefs.
const _kLegacySectorKeys = [
  'settings.sector_top_left',
  'settings.sector_top_right',
  'settings.sector_bottom_left',
  'settings.sector_bottom_right',
];

/// Legacy keys from before "show brightest/darkest point" were merged
/// into a single "show extreme light spots" switch. Migrated on load so
/// pre-existing installs keep their choice: either one was on, means the
/// merged switch starts on too.
const _kLegacyShowBrightestPointKey = 'settings.show_brightest_point';
const _kLegacyShowDarkestPointKey = 'settings.show_darkest_point';

/// Parses a persisted [AppThemeMode] name back into the enum, falling
/// back to the documented default for a missing/unrecognized value
/// (e.g. `null` on first launch, or a stale name from a future app
/// version rolled back).
AppThemeMode _themeModeFromName(String? name) {
  return AppThemeMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => const AppSettings().themeMode,
  );
}

/// SharedPreferences-backed [SettingsRepository]. Missing keys (first
/// launch) fall back to the documented [AppSettings] defaults - that is
/// expected, ordinary "not set yet" state, not a validation failure.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  @override
  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const defaults = AppSettings();
      final legacyExtremeSpots =
          prefs.getBool(_kLegacyShowBrightestPointKey) ??
          prefs.getBool(_kLegacyShowDarkestPointKey);
      final loaded = AppSettings(
        detectColorPeaks:
            prefs.getBool(_kDetectColorPeaksKey) ?? defaults.detectColorPeaks,
        spectrumUnit: (prefs.getBool(_kSpectrumUnitKey) ?? false)
            ? SpectrumUnit.frequencyHz
            : SpectrumUnit.wavelengthNm,
        showExtremeLightSpots:
            prefs.getBool(_kShowExtremeLightSpotsKey) ??
            legacyExtremeSpots ??
            defaults.showExtremeLightSpots,
        enhanceColors:
            prefs.getBool(_kEnhanceColorsKey) ?? defaults.enhanceColors,
        themeMode: _themeModeFromName(prefs.getString(_kThemeModeKey)),
        chartsAtTop: prefs.getBool(_kChartsAtTopKey) ?? defaults.chartsAtTop,
      );
      return loaded;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load persisted settings',
        error: error,
        stackTrace: stackTrace,
      );
      throw SettingsPersistenceFailure('Unable to load settings: $error');
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDetectColorPeaksKey, settings.detectColorPeaks);
      await prefs.setBool(
        _kSpectrumUnitKey,
        settings.spectrumUnit == SpectrumUnit.frequencyHz,
      );
      await prefs.setBool(
        _kShowExtremeLightSpotsKey,
        settings.showExtremeLightSpots,
      );
      await prefs.setBool(_kEnhanceColorsKey, settings.enhanceColors);
      await prefs.setString(_kThemeModeKey, settings.themeMode.name);
      await prefs.setBool(_kChartsAtTopKey, settings.chartsAtTop);
      // Drop the superseded legacy keys once we've saved under the new
      // keys, so a future load() never has stale legacy data to migrate
      // from again.
      await prefs.remove(_kLegacyShowBrightestPointKey);
      await prefs.remove(_kLegacyShowDarkestPointKey);
      for (final key in _kLegacySectorKeys) {
        await prefs.remove(key);
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to persist settings',
        error: error,
        stackTrace: stackTrace,
      );
      throw SettingsPersistenceFailure('Unable to save settings: $error');
    }
  }
}
