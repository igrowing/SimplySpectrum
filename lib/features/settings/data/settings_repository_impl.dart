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
const _kTopLeftSectorKey = 'settings.sector_top_left';
const _kTopRightSectorKey = 'settings.sector_top_right';
const _kBottomLeftSectorKey = 'settings.sector_bottom_left';
const _kBottomRightSectorKey = 'settings.sector_bottom_right';

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

/// Parses a persisted [SectorWidgetType] name back into the enum,
/// falling back to [fallback] for a missing/unrecognized value.
SectorWidgetType _sectorWidgetFromName(
  String? name,
  SectorWidgetType fallback,
) {
  return SectorWidgetType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => fallback,
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
        topLeftSector: _sectorWidgetFromName(
          prefs.getString(_kTopLeftSectorKey),
          defaults.topLeftSector,
        ),
        topRightSector: _sectorWidgetFromName(
          prefs.getString(_kTopRightSectorKey),
          defaults.topRightSector,
        ),
        bottomLeftSector: _sectorWidgetFromName(
          prefs.getString(_kBottomLeftSectorKey),
          defaults.bottomLeftSector,
        ),
        bottomRightSector: _sectorWidgetFromName(
          prefs.getString(_kBottomRightSectorKey),
          defaults.bottomRightSector,
        ),
      );
      // Guard against a corrupt/partially-migrated sector layout (e.g. a
      // future app version's arrangement rolled back to this one, or
      // prefs edited/restored out of band) producing a duplicated or
      // missing sector widget - fall back to the default arrangement
      // entirely rather than render a broken grid.
      return loaded.hasValidSectorLayout
          ? loaded
          : loaded.copyWith(
              topLeftSector: defaults.topLeftSector,
              topRightSector: defaults.topRightSector,
              bottomLeftSector: defaults.bottomLeftSector,
              bottomRightSector: defaults.bottomRightSector,
            );
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
      await prefs.setString(_kTopLeftSectorKey, settings.topLeftSector.name);
      await prefs.setString(
        _kTopRightSectorKey,
        settings.topRightSector.name,
      );
      await prefs.setString(
        _kBottomLeftSectorKey,
        settings.bottomLeftSector.name,
      );
      await prefs.setString(
        _kBottomRightSectorKey,
        settings.bottomRightSector.name,
      );
      // Drop the superseded legacy keys once we've saved under the new
      // merged key, so a future load() never has stale legacy data to
      // migrate from again.
      await prefs.remove(_kLegacyShowBrightestPointKey);
      await prefs.remove(_kLegacyShowDarkestPointKey);
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
