import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:simply_spectrum/core/services/platform_service.dart';

/// Tracks the "Keep screen on" (wakelock) toggle shown in the Controls
/// sector, as its own app-root-scoped view model rather than local
/// State on the Controls sector widget itself.
///
/// The Controls sector's own widget subtree gets torn down and rebuilt
/// for reasons that have nothing to do with this toggle - a device
/// rotation swaps the horizontal/vertical layout's `Row`/`Column`
/// composition, and the "Charts placement" setting reorders which half
/// of the screen it sits in - and each of those previously destroyed
/// the widget's local `State`, running its `dispose()` and turning the
/// wakelock back off out from under the user. Living here instead,
/// alongside the other app-lifetime view models wired up in
/// `main.dart`, means the toggle only ever changes when the user
/// actually taps it.
class ScreenWakeViewModel extends ChangeNotifier {
  bool _keepScreenOn = false;

  bool get keepScreenOn => _keepScreenOn;

  Future<void> toggle() async {
    final next = !_keepScreenOn;
    await PlatformService.setWakelock(next);
    _keepScreenOn = next;
    notifyListeners();
  }

  @override
  void dispose() {
    // Never leave the screen forced on once the app itself is torn
    // down - unlike the old per-widget dispose(), this now only fires
    // at true app teardown, not on every layout reshuffle.
    if (_keepScreenOn) {
      unawaited(PlatformService.setWakelock(false));
    }
    super.dispose();
  }
}
