import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simply_spectrum/core/widgets/translucent_icon_button.dart';

void main() {
  group('TranslucentIconButton', () {
    Future<void> pump(WidgetTester tester, Widget button) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: button)),
      ),
    );

    testWidgets('renders the plain icon and fires onPressed when tapped', (
      tester,
    ) async {
      var tapped = false;
      await pump(
        tester,
        TranslucentIconButton(
          icon: Icons.ac_unit,
          semanticLabel: 'Freeze',
          onPressed: () => tapped = true,
        ),
      );

      expect(find.byIcon(Icons.ac_unit), findsOneWidget);
      // No strike bar without the flag.
      expect(
        find.byKey(const Key('translucentIconButton_strikethrough')),
        findsNothing,
      );

      await tester.tap(find.byType(TranslucentIconButton));
      expect(tapped, isTrue);
    });

    testWidgets('draws a diagonal strike bar when strikethrough is true', (
      tester,
    ) async {
      await pump(
        tester,
        TranslucentIconButton(
          icon: Icons.ac_unit,
          semanticLabel: 'Resume',
          strikethrough: true,
          onPressed: () {},
        ),
      );

      expect(find.byIcon(Icons.ac_unit), findsOneWidget);
      expect(
        find.byKey(const Key('translucentIconButton_strikethrough')),
        findsOneWidget,
      );
    });
  });
}
