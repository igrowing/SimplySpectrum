import 'package:simply_spectrum/features/settings/domain/app_settings.dart';

/// Persists and restores user settings so the app remembers the user's
/// choices across restarts.
abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}
