import 'package:get_it/get_it.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/camera_feed/data/camera_repository_impl.dart';
import 'package:simply_spectrum/features/camera_feed/domain/camera_repository.dart';
import 'package:simply_spectrum/features/settings/data/settings_repository_impl.dart';
import 'package:simply_spectrum/features/settings/domain/settings_repository.dart';
import 'package:simply_spectrum/features/snapshot/data/snapshot_repository_impl.dart';
import 'package:simply_spectrum/features/snapshot/domain/snapshot_repository.dart';

final GetIt sl = GetIt.instance;

/// Registers every long-lived dependency. Called once from `main()` before
/// `runApp`. Kept centralized per project rules - never instantiate
/// long-lived service objects inline in widgets.
void setupInjection() {
  sl
    ..registerLazySingleton<AppLogger>(DeveloperAppLogger.new)
    ..registerLazySingleton<CameraRepositoryImpl>(
      () => CameraRepositoryImpl(logger: sl()),
    )
    ..registerLazySingleton<CameraRepository>(() => sl<CameraRepositoryImpl>())
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(logger: sl()),
    )
    ..registerLazySingleton<SnapshotRepository>(
      () => SnapshotRepositoryImpl(logger: sl()),
    );
}

/// Test helper: clears all registrations so each test starts fresh.
Future<void> resetInjection() => sl.reset();
