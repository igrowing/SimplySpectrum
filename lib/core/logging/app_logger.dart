import 'dart:developer' as developer;

/// Interface-wrapped logging service.
///
/// Project rules forbid raw `print()`/`debugPrint()` calls scattered through
/// the codebase. All logging must go through this interface so the sink can
/// be swapped (e.g. for crash reporting) without touching call sites.
abstract class AppLogger {
  void info(String message, {String? tag});
  void warning(String message, {String? tag});
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  });
}

/// Default implementation backed by `dart:developer`, which is safe for
/// release builds (routed to the observatory/DevTools log stream instead of
/// stdout) and does not trigger the "no print statements" lint concerns.
class DeveloperAppLogger implements AppLogger {
  const DeveloperAppLogger();

  @override
  void info(String message, {String? tag}) {
    developer.log(message, name: tag ?? 'SimplySpectrum', level: 800);
  }

  @override
  void warning(String message, {String? tag}) {
    developer.log(message, name: tag ?? 'SimplySpectrum', level: 900);
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    developer.log(
      message,
      name: tag ?? 'SimplySpectrum',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
