// Smoke test for the Settings screen: the one screen that can be
// meaningfully widget-tested without a real camera (the `camera` plugin
// requires platform channels/hardware that aren't available in the test
// environment - see agents.md's testing notes).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/settings/data/settings_repository_impl.dart';
import 'package:simply_spectrum/features/settings/domain/app_settings.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_screen.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';

void main() {
  testWidgets('SettingsScreen renders all four switches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final viewModel = SettingsViewModel(
      repository: SettingsRepositoryImpl(logger: const DeveloperAppLogger()),
      logger: const DeveloperAppLogger(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<SettingsViewModel>.value(
          value: viewModel,
          child: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detect color peaks'), findsOneWidget);
    expect(find.text('Show color in wave frequency (Hz)'), findsOneWidget);
    expect(find.text('Show the extreme light spots'), findsOneWidget);
    expect(find.text('Enhance colors'), findsOneWidget);

    // Default: "Detect color peaks" is on, everything else off.
    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    expect(switches[0].value, isTrue);
    expect(switches[1].value, isFalse);
    expect(switches[2].value, isFalse);
    expect(switches[3].value, isFalse);

    // Toggling persists through the repository (non-volatile settings).
    await tester.tap(find.text('Enhance colors'));
    await tester.pumpAndSettle();
    expect(viewModel.settings.enhanceColors, isTrue);

    // The theme picker defaults to "System" and switching segments
    // updates the persisted setting.
    expect(find.text('Theme'), findsOneWidget);
    expect(viewModel.settings.themeMode, AppThemeMode.system);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(viewModel.settings.themeMode, AppThemeMode.dark);

    // The "Charts placement" segmented toggle defaults to charts-first
    // (chartsAtTop == true). Its labels track the current orientation:
    // the default test surface is landscape, so they read Left/Right.
    expect(find.text('Charts placement'), findsOneWidget);
    expect(viewModel.settings.chartsAtTop, isTrue);
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Top'), findsNothing);

    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();
    expect(viewModel.settings.chartsAtTop, isFalse);

    // In portrait the same toggle relabels to Top/Bottom.
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(find.text('Top'), findsOneWidget);
    expect(find.text('Bottom'), findsOneWidget);
    expect(find.text('Left'), findsNothing);

    // Scroll down to reach the footer at the bottom of the list, which
    // is now off the default viewport with the new section above it.
    await tester.scrollUntilVisible(
      find.text('Buy me a coffee'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Buy me a coffee'), findsOneWidget);
  });
}
