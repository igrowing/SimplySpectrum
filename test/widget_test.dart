// Smoke test for the Settings sector: the one sector that can be
// meaningfully widget-tested without a real camera (the `camera` plugin
// requires platform channels/hardware that aren't available in the test
// environment - see agents.md's testing notes).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simply_spectrum/core/logging/app_logger.dart';
import 'package:simply_spectrum/features/settings/data/settings_repository_impl.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_sector_widget.dart';
import 'package:simply_spectrum/features/settings/presentation/settings_view_model.dart';

void main() {
  testWidgets(
    'SettingsSectorWidget renders all five switches with a visible scrollbar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final viewModel = SettingsViewModel(
        repository: SettingsRepositoryImpl(logger: const DeveloperAppLogger()),
        logger: const DeveloperAppLogger(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsViewModel>.value(
            value: viewModel,
            child: const Scaffold(body: SettingsSectorWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detect color peaks'), findsOneWidget);
      expect(
        find.text('Show color in wave frequency (Hz)'),
        findsOneWidget,
      );
      expect(find.text('Show the most luminous point'), findsOneWidget);
      expect(find.text('Show the darkest point'), findsOneWidget);
      expect(find.text('Enhance colors'), findsOneWidget);
      expect(find.byType(Scrollbar), findsOneWidget);

      // Default: "Detect color peaks" is on, everything else off.
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches[0].value, isTrue);
      expect(switches[1].value, isFalse);
      expect(switches[2].value, isFalse);
      expect(switches[3].value, isFalse);
      expect(switches[4].value, isFalse);

      // Toggling persists through the repository (non-volatile settings).
      await tester.tap(find.text('Enhance colors'));
      await tester.pumpAndSettle();
      expect(viewModel.settings.enhanceColors, isTrue);
    },
  );
}
