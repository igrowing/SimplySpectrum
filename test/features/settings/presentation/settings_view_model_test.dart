import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/core/error/failure.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/domain/settings_repository.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';

class _FakeSettingsRepository implements SettingsRepository {
  AppSettings? loadResult;
  Exception? loadError;
  Exception? saveError;
  AppSettings? lastSaved;
  int saveCallCount = 0;

  @override
  Future<AppSettings> load() async {
    if (loadError != null) throw loadError!;
    return loadResult ?? const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async {
    saveCallCount++;
    lastSaved = settings;
    if (saveError != null) throw saveError!;
  }
}

class _RecordingLogger implements AppLogger {
  final warnings = <String>[];
  final errors = <String>[];

  @override
  void info(String message, {String? tag}) {}

  @override
  void warning(String message, {String? tag}) => warnings.add(message);

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) => errors.add(message);
}

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  group('SettingsViewModel', () {
    test(
      'starts unloaded and loads the repository value on construction',
      () async {
        final repository = _FakeSettingsRepository()
          ..loadResult = const AppSettings(
            detectColorPeaks: false,
            enhanceColors: true,
          );
        final viewModel = SettingsViewModel(
          repository: repository,
          logger: _RecordingLogger(),
        );

        expect(viewModel.isLoaded, isFalse);
        await _flushMicrotasks();

        expect(viewModel.isLoaded, isTrue);
        expect(viewModel.settings.detectColorPeaks, isFalse);
        expect(viewModel.settings.enhanceColors, isTrue);
      },
    );

    test(
      'falls back to defaults and logs a warning when load() fails',
      () async {
        final repository = _FakeSettingsRepository()
          ..loadError = const SettingsPersistenceFailure('disk error');
        final logger = _RecordingLogger();
        final viewModel = SettingsViewModel(
          repository: repository,
          logger: logger,
        );

        await _flushMicrotasks();

        expect(viewModel.isLoaded, isTrue);
        expect(viewModel.settings, const AppSettings());
        expect(logger.warnings, hasLength(1));
      },
    );

    test(
      'setDetectColorPeaks updates state immediately and persists',
      () async {
        final repository = _FakeSettingsRepository();
        final viewModel = SettingsViewModel(
          repository: repository,
          logger: _RecordingLogger(),
        );
        await _flushMicrotasks();

        await viewModel.setDetectColorPeaks(false);

        expect(viewModel.settings.detectColorPeaks, isFalse);
        expect(repository.lastSaved?.detectColorPeaks, isFalse);
      },
    );

    test('setSpectrumUnit updates only that field', () async {
      final repository = _FakeSettingsRepository();
      final viewModel = SettingsViewModel(
        repository: repository,
        logger: _RecordingLogger(),
      );
      await _flushMicrotasks();

      await viewModel.setSpectrumUnit(SpectrumUnit.frequencyHz);

      expect(viewModel.settings.spectrumUnit, SpectrumUnit.frequencyHz);
      expect(viewModel.settings.detectColorPeaks, isTrue);
    });

    test('setShowExtremeLightSpots updates only that field', () async {
      final repository = _FakeSettingsRepository();
      final viewModel = SettingsViewModel(
        repository: repository,
        logger: _RecordingLogger(),
      );
      await _flushMicrotasks();

      await viewModel.setShowExtremeLightSpots(true);

      expect(viewModel.settings.showExtremeLightSpots, isTrue);
    });

    test('setEnhanceColors updates only that field', () async {
      final repository = _FakeSettingsRepository();
      final viewModel = SettingsViewModel(
        repository: repository,
        logger: _RecordingLogger(),
      );
      await _flushMicrotasks();

      await viewModel.setEnhanceColors(true);

      expect(viewModel.settings.enhanceColors, isTrue);
    });

    test('setThemeMode updates only that field and persists', () async {
      final repository = _FakeSettingsRepository();
      final viewModel = SettingsViewModel(
        repository: repository,
        logger: _RecordingLogger(),
      );
      await _flushMicrotasks();

      await viewModel.setThemeMode(AppThemeMode.dark);

      expect(viewModel.settings.themeMode, AppThemeMode.dark);
      expect(viewModel.settings.detectColorPeaks, isTrue);
      expect(repository.lastSaved?.themeMode, AppThemeMode.dark);
    });

    test('notifies listeners on load and on every update', () async {
      final repository = _FakeSettingsRepository();
      final viewModel = SettingsViewModel(
        repository: repository,
        logger: _RecordingLogger(),
      );
      var notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      await _flushMicrotasks();
      expect(notifyCount, 1);

      await viewModel.setEnhanceColors(true);
      expect(notifyCount, 2);
    });

    test('logs an error (but keeps the new value) when save() fails', () async {
      final repository = _FakeSettingsRepository()
        ..saveError = const SettingsPersistenceFailure('disk full');
      final logger = _RecordingLogger();
      final viewModel = SettingsViewModel(
        repository: repository,
        logger: logger,
      );
      await _flushMicrotasks();

      await viewModel.setEnhanceColors(true);

      // The in-memory setting still reflects the user's change even
      // though persisting it failed - only the save was rejected.
      expect(viewModel.settings.enhanceColors, isTrue);
      expect(logger.errors, hasLength(1));
    });
  });
}
