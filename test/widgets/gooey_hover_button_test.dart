import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/theme/app_theme.dart';
import 'package:gearstock/widgets/gooey_hover_button.dart';

void main() {
  testWidgets(
    'gooey hover animates around the pointer without hiding content',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: GooeyHoverButton(
                child: ElevatedButton(
                  key: const ValueKey('gooey-test-button'),
                  onPressed: () {},
                  child: const Text('Continue'),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('gooey-test-button'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(tester.takeException(), isNull);
      await gesture.removePointer();
    },
  );
}
