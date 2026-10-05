import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/features/auth/data/auth_repository.dart';
import 'package:gearstock/features/auth/domain/auth_state.dart';
import 'package:gearstock/features/auth/presentation/auth_notifier.dart';
import 'package:gearstock/features/auth/presentation/login_screen.dart';
import 'package:gearstock/l10n/gen/app_localizations.dart';
import 'package:gearstock/theme/app_theme.dart';

class _LoginAuthRepository extends Fake implements AuthRepository {
  @override
  Future<AuthState> currentSession() async => const Unauthenticated();

  @override
  Future<AuthState> signIn({
    required String email,
    required String password,
  }) async => const Unauthenticated();

  @override
  Future<void> signOut() async {}

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets(
      'login fields and labels adapt to ${theme.brightness.name} theme',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_LoginAuthRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: theme.brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('GearStock'), findsOneWidget);
        expect(
          find.text('Bicycle Workshop & Inventory Management'),
          findsOneWidget,
        );
        expect(find.text('codesalph92@gmail.com'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('theme-mode-selector')),
          findsOneWidget,
        );

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, theme.colorScheme.surface);
      },
    );
  }
}
