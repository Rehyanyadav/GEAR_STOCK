import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/l10n/gen/app_localizations.dart';
import 'package:gearstock/theme/app_theme.dart';
import 'package:gearstock/widgets/app_splash_overlay.dart';

void main() {
  testWidgets('splash fades away to the routed screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppSplashOverlay(
          child: Scaffold(body: Center(child: Text('Home content'))),
        ),
      ),
    );

    expect(find.text('GearStock'), findsOneWidget);
    expect(find.text('Home content'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('GearStock'), findsNothing);
    expect(find.text('Home content'), findsOneWidget);
  });

  testWidgets('reduced motion skips the startup reveal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const AppSplashOverlay(
            child: Scaffold(body: Center(child: Text('Home content'))),
          ),
        ),
      ),
    );

    expect(find.text('Home content'), findsOneWidget);
    expect(find.text('GearStock'), findsNothing);
  });
}
