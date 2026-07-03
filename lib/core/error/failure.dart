import 'package:equatable/equatable.dart';

/// Base class for all typed domain failures.
///
/// Per project rules, errors are never silently swallowed. Any recoverable
/// error condition must be represented as a [Failure] subtype and either
/// surfaced to the presentation layer or logged via the app logger.
abstract class Failure extends Equatable implements Exception {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

/// Raised when the device camera cannot be initialized or accessed.
class CameraFailure extends Failure {
  const CameraFailure(super.message);
}

/// Raised when a camera frame cannot be parsed/analyzed.
class FrameProcessingFailure extends Failure {
  const FrameProcessingFailure(super.message);
}

/// Raised when persisted settings cannot be read or written.
class SettingsPersistenceFailure extends Failure {
  const SettingsPersistenceFailure(super.message);
}

/// Raised when a screen snapshot cannot be captured or saved.
class SnapshotFailure extends Failure {
  const SnapshotFailure(super.message);
}

/// Raised when a required runtime permission is denied.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
