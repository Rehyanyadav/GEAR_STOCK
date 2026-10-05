import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';


import 'package:gearstock/features/auth/data/auth_repository.dart';
import 'package:gearstock/features/auth/domain/auth_state.dart';
import 'package:gearstock/features/auth/presentation/auth_notifier.dart';
import 'package:gearstock/features/auth/presentation/login_screen.dart';
import 'package:gearstock/l10n/gen/app_localizations.dart';
import 'package:gearstock/theme/app_theme.dart';

// ── Fakes & mocks ───────────────────────────────────────────────────────────

class _FakeAuthRepository extends Fake implements AuthRepository {
  /// Configures what [signIn] returns or throws.
  Object? signInResult; // AuthState or AuthException

  @override
  Future<AuthState> currentSession() async => const Unauthenticated();

  @override
  Future<AuthState> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final r = signInResult;
    if (r is AuthException) throw r;
    return r as AuthState;
  }

  @override
  Future<void> signOut() async {}

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Widget _buildSubject(_FakeAuthRepository fakeRepo) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeRepo),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoginScreen(),
    ),
  );
}

Future<void> _fillAndSubmit(
  WidgetTester tester, {
  String email = 'staff@gearstock.in',
  String password = 'mechanic2026',
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login to Shop'));
  await tester.pump();
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _FakeAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = _FakeAuthRepository();
  });

  // 1 ─────────────────────────────────────────────────────────────────────────
  testWidgets('1. renders email and password fields', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'Login to Shop'), findsOneWidget);
  });

  // 2 ─────────────────────────────────────────────────────────────────────────
  testWidgets('2. empty email shows validation error', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    // Clear the pre-filled email value.
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login to Shop'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
  });

  // 3 ─────────────────────────────────────────────────────────────────────────
  testWidgets('3. invalid email shows format error', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextFormField).first, 'notanemail');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login to Shop'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  // 4 ─────────────────────────────────────────────────────────────────────────
  testWidgets('4. short password shows length error', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextFormField).first, 'staff@gearstock.in');
    await tester.enterText(find.byType(TextFormField).last, 'abc');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login to Shop'));
    await tester.pump();

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  // 5 ─────────────────────────────────────────────────────────────────────────
  testWidgets('5. spinner visible while loading', (tester) async {
    fakeRepo.signInResult =
        const Authenticated(userId: 'u1', email: 'staff@gearstock.in');

    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    await _fillAndSubmit(tester);
    // One pump — auth call is in flight.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
  });

  // 6 ─────────────────────────────────────────────────────────────────────────
  testWidgets('6. button disabled while loading', (tester) async {
    fakeRepo.signInResult =
        const Authenticated(userId: 'u1', email: 'staff@gearstock.in');

    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    await _fillAndSubmit(tester);
    // During loading the ElevatedButton should have onPressed == null.
    final button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(button.onPressed, isNull);
    await tester.pump(const Duration(milliseconds: 50));
  });

  // 7 ─────────────────────────────────────────────────────────────────────────
  testWidgets('7. wrong credentials shows error banner', (tester) async {
    fakeRepo.signInResult = const WrongCredentials();

    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    await _fillAndSubmit(tester);
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Incorrect email or password. Please try again.'),
      findsOneWidget,
    );
  });

  // 8 ─────────────────────────────────────────────────────────────────────────
  testWidgets('8. no internet shows distinct banner', (tester) async {
    fakeRepo.signInResult = const NoInternet();

    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    await _fillAndSubmit(tester);
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('No internet connection. Check your network and retry.'),
      findsOneWidget,
    );
  });

  // 9 ─────────────────────────────────────────────────────────────────────────
  testWidgets('9. server error shows banner with message', (tester) async {
    fakeRepo.signInResult = const ServerError('timeout');

    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    await _fillAndSubmit(tester);
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    expect(find.text('Server error: timeout'), findsOneWidget);
  });

  // 10 ────────────────────────────────────────────────────────────────────────
  testWidgets('10. password visibility toggle flips obscureText', (tester) async {
    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    // Password field starts obscured.
    final passwordField = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(passwordField.obscureText, isTrue);

    // Tap the eye icon button.
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    final passwordFieldAfter = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(passwordFieldAfter.obscureText, isFalse);
  });

  // 11 ────────────────────────────────────────────────────────────────────────
  testWidgets('11. keyboard "next" action moves focus to password field',
      (tester) async {
    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));

    final emailField = find.byType(TextFormField).first;
    await tester.tap(emailField);
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    // Password field should now have focus.
    final passwordField = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    expect(
      (passwordField.focusNode ?? FocusNode()).hasFocus,
      isTrue,
    );
  });

  testWidgets('rate limit displays feedback and temporarily disables submit',
      (tester) async {
    fakeRepo.signInResult =
        const RateLimited(retryAfter: Duration(seconds: 2));

    await tester.pumpWidget(_buildSubject(fakeRepo));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _fillAndSubmit(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(
      find.text('Too many login attempts. Wait 2 seconds and try again.'),
      findsOneWidget,
    );
    var button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(seconds: 2));
    button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });
}
