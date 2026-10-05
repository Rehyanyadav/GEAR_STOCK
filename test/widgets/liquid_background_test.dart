import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/theme/app_theme.dart';
import 'package:gearstock/widgets/liquid_background.dart';

void main() {
  testWidgets('liquid background animates without obscuring its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: LiquidBackground(child: Center(child: Text('Login form'))),
        ),
      ),
    );

    expect(find.text('Login form'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Login form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
