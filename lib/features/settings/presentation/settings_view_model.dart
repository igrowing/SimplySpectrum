import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/domain/settings_repository.dart';

/// Loads persisted settings on start and persists every change, so
/// exiting/re-entering the app restores the user's previous choices.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsRepository repository,
    required AppLogger logger,
  }) : _repository = repository,
       _logger = logger {
    unawaited(_load());
  }

  final SettingsRepository _repository;
  final AppLogger _logger;

  AppSettings _settings = const AppSettings();
  bool _isLoaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  Future<void> _load() async {
    try {
      _settings = await _repository.load();
    } on SettingsPersistenceFailure catch (error) {
      _logger.warning('Using default settings after load failure: $error');
      _settings = const AppSettings();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _update(AppSettings Function(AppSettings) transform) async {
    final next = transform(_settings);
    _settings = next;
    notifyListeners();
    try {
      await _repository.save(next);
    } on SettingsPersistenceFailure catch (error, stackTrace) {
      _logger.error(
        'Failed to persist settings change',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setDetectColorPeaks(bool value) =>
      _update((s) => s.copyWith(detectColorPeaks: value));

  Future<void> setSpectrumUnit(SpectrumUnit value) =>
      _update((s) => s.copyWith(spectrumUnit: value));

  Future<void> setShowBrightestPoint(bool value) =>
      _update((s) => s.copyWith(showBrightestPoint: value));

  Future<void> setShowDarkestPoint(bool value) =>
      _update((s) => s.copyWith(showDarkestPoint: value));

  Future<void> setEnhanceColors(bool value) =>
      _update((s) => s.copyWith(enhanceColors: value));
}
