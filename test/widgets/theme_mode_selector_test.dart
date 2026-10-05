
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/theme/theme_mode_provider.dart';
import 'package:gearstock/widgets/theme_mode_selector.dart';

void main() {
  testWidgets(
    'theme selector offers and applies system, light, and dark modes',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: ThemeModeSelector(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('System'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('theme-mode-selector')));
      await tester.pumpAndSettle();
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(find.text('Dark'), findsOneWidget);
    },
  );
}
