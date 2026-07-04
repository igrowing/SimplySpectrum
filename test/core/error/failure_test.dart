import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/core/error/failure.dart';

void main() {
  group('Failure', () {
    test('is an Exception, so it can be thrown/caught as one', () {
      const failure = CameraFailure('camera unavailable');

      expect(failure, isA<Exception>());
    });

    test('toString includes the runtime type and message', () {
      const failure = CameraFailure('camera unavailable');

      expect(failure.toString(), 'CameraFailure: camera unavailable');
    });

    test('equality is structural and based on message + type', () {
      expect(
        const CameraFailure('same message'),
        const CameraFailure('same message'),
      );
      expect(
        const CameraFailure('one message') ==
            const CameraFailure('different message'),
        isFalse,
      );
    });

    test(
      'two different Failure subtypes with the same message are not equal',
      () {
        // Equatable's props only include `message`, but `runtimeType`
        // differs between subtypes, and Equatable folds runtimeType into
        // its equality check by default via `==` on distinct classes.
        expect(
          const CameraFailure('x') == const FrameProcessingFailure('x'),
          isFalse,
        );
      },
    );

    test('every documented Failure subtype carries its message', () {
      const failures = <Failure>[
        CameraFailure('camera'),
        FrameProcessingFailure('frame'),
        SettingsPersistenceFailure('settings'),
        SnapshotFailure('snapshot'),
        PermissionFailure('permission'),
      ];

      for (final failure in failures) {
        expect(failure.message, isNotEmpty);
        expect(failure.props, [failure.message]);
      }
    });
  });
}
