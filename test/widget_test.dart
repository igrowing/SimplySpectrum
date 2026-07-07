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

    // The "Main screen order" grid shows the default arrangement.
    expect(find.text('Main screen order'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Color chart'), findsOneWidget);
    expect(find.text('Luminosity chart'), findsOneWidget);
    expect(find.text('Controls'), findsOneWidget);

    // Assigning Controls to the top-left dropdown (currently Camera)
    // swaps the two: Controls moves to top-left, and Camera - what
    // used to be there - takes over wherever Controls was (bottom-right).
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    // The opened menu re-lists all 4 options; the last "Controls" match
    // is the menu item (the other is the still-visible bottom-right
    // dropdown showing its current selection).
    await tester.tap(find.text('Controls').last);
    await tester.pumpAndSettle();

    expect(viewModel.settings.topLeftSector, SectorWidgetType.controls);
    expect(viewModel.settings.bottomRightSector, SectorWidgetType.camera);
    expect(viewModel.settings.topRightSector, SectorWidgetType.colorChart);
    expect(
      viewModel.settings.bottomLeftSector,
      SectorWidgetType.luminosityChart,
    );

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
