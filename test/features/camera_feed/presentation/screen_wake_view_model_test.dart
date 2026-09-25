import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/features/camera_feed/presentation/screen_wake_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('simply_spectrum/platform');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ScreenWakeViewModel', () {
    test('starts with the screen wakelock off', () {
      final viewModel = ScreenWakeViewModel();
      expect(viewModel.keepScreenOn, isFalse);
    });

    test('toggle() turns the wakelock on and notifies listeners', () async {
      final viewModel = ScreenWakeViewModel();
      var notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      await viewModel.toggle();

      expect(viewModel.keepScreenOn, isTrue);
      expect(notifyCount, 1);
      expect(calls, [
        isA<MethodCall>()
            .having((c) => c.method, 'method', 'setWakelock')
            .having((c) => c.arguments, 'arguments', {'enabled': true}),
      ]);
    });

    test('toggle() again turns the wakelock back off', () async {
      final viewModel = ScreenWakeViewModel();
      await viewModel.toggle();
      calls.clear();

      await viewModel.toggle();

      expect(viewModel.keepScreenOn, isFalse);
      expect(calls, [
        isA<MethodCall>()
            .having((c) => c.method, 'method', 'setWakelock')
            .having((c) => c.arguments, 'arguments', {'enabled': false}),
      ]);
    });

    // Regression test for the reported bug: rotating the device (which
    // swaps the main screen's Row/Column composition) or flipping the
    // "Charts placement" setting (which reorders the main screen's
    // halves) used to tear down and recreate the Controls sector's own
    // local State, whose dispose() unconditionally turned the wakelock
    // back off - so "Keep screen on" silently reset itself on either
    // action. Now that the toggle lives here, at the app root, neither
    // kind of Controls-sector rebuild can reach it: reading the state
    // repeatedly (standing in for however many such rebuilds happen)
    // never changes it and never re-invokes the platform channel.
    test('stays on across repeated reads, standing in for Controls-sector '
        'rebuilds from rotation or a "Charts placement" change, without '
        're-invoking the platform channel', () async {
      final viewModel = ScreenWakeViewModel();
      await viewModel.toggle();
      calls.clear();

      for (var i = 0; i < 5; i++) {
        expect(viewModel.keepScreenOn, isTrue);
      }
      expect(calls, isEmpty);
    });

    test('dispose() turns the wakelock off if it was left on', () async {
      final viewModel = ScreenWakeViewModel();
      await viewModel.toggle();
      calls.clear();

      viewModel.dispose();
      // The platform call inside dispose() is fire-and-forget.
      await Future<void>.delayed(Duration.zero);

      expect(calls, [
        isA<MethodCall>()
            .having((c) => c.method, 'method', 'setWakelock')
            .having((c) => c.arguments, 'arguments', {'enabled': false}),
      ]);
    });

    test(
      'dispose() does nothing if the wakelock was never turned on',
      () async {
        final viewModel = ScreenWakeViewModel();

        // A cascade here would blur the "arrange, then act" shape of
        // the test.
        // ignore: cascade_invocations
        viewModel.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(calls, isEmpty);
      },
    );
  });
}
