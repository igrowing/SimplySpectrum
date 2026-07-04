import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';

void main() {
  group('DeveloperAppLogger', () {
    // `dart:developer`'s `log()` writes to the VM service stream, not
    // stdout, so there's nothing to capture from the test process. These
    // tests instead assert the one thing that actually matters for a
    // thin `dart:developer` wrapper: every method call completes without
    // throwing, for every parameter combination callers rely on.
    const logger = DeveloperAppLogger();

    test('is usable as the AppLogger interface', () {
      expect(logger, isA<AppLogger>());
    });

    test('info() runs without throwing, with and without a tag', () {
      expect(() => logger.info('hello'), returnsNormally);
      expect(() => logger.info('hello', tag: 'MyTag'), returnsNormally);
    });

    test('warning() runs without throwing, with and without a tag', () {
      expect(() => logger.warning('careful'), returnsNormally);
      expect(() => logger.warning('careful', tag: 'MyTag'), returnsNormally);
    });

    test('error() runs without throwing with just a message', () {
      expect(() => logger.error('boom'), returnsNormally);
    });

    test(
      'error() runs without throwing with an attached error and '
      'stack trace',
      () {
        expect(
          () => logger.error(
            'boom',
            error: StateError('bad state'),
            stackTrace: StackTrace.current,
            tag: 'MyTag',
          ),
          returnsNormally,
        );
      },
    );
  });
}
