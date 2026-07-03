import 'package:shared_preferences/shared_preferences.dart';

import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/domain/settings_repository.dart';

const _kDetectColorPeaksKey = 'settings.detect_color_peaks';
const _kSpectrumUnitKey = 'settings.spectrum_unit_is_frequency';
const _kShowBrightestPointKey = 'settings.show_brightest_point';
const _kShowDarkestPointKey = 'settings.show_darkest_point';
const _kEnhanceColorsKey = 'settings.enhance_colors';

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
      return AppSettings(
        detectColorPeaks:
            prefs.getBool(_kDetectColorPeaksKey) ?? defaults.detectColorPeaks,
        spectrumUnit: (prefs.getBool(_kSpectrumUnitKey) ?? false)
            ? SpectrumUnit.frequencyHz
            : SpectrumUnit.wavelengthNm,
        showBrightestPoint:
            prefs.getBool(_kShowBrightestPointKey) ??
            defaults.showBrightestPoint,
        showDarkestPoint:
            prefs.getBool(_kShowDarkestPointKey) ?? defaults.showDarkestPoint,
        enhanceColors:
            prefs.getBool(_kEnhanceColorsKey) ?? defaults.enhanceColors,
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
        _kShowBrightestPointKey,
        settings.showBrightestPoint,
      );
      await prefs.setBool(_kShowDarkestPointKey, settings.showDarkestPoint);
      await prefs.setBool(_kEnhanceColorsKey, settings.enhanceColors);
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
