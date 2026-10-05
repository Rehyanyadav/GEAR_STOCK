import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router.dart';
import 'features/sync/data/sync_runner.dart';
import 'l10n/gen/app_localizations.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_provider.dart';
import 'widgets/app_splash_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load .env before anything else — Supabase inict reads from it.
  await dotenv.load(fileName: '.env');

  // Initialize Sentry for crash reporting (only if DSN is valid URL).
  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (sentryDsn.startsWith('http')) {
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = sentryDsn
          ..environment = kReleaseMode
              ? 'production'
              : kProfileMode
              ? 'profile'
              : 'development'
          ..tracesSampleRate = 0.2
          ..enableAutoPerformanceTracing = true
          ..enableAutoSessionTracking = true
          ..enableNativeCrashHandling = true
          ..sendDefaultPii = false
          ..debug = false;
      },
      appRunner: () async {
        await _initializeSupabase();
        _runApp();
      },
    );
    return;
  }

  await _initializeSupabase();
  _runApp();
}

Future<void> _initializeSupabase() {
  return Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey:
        dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
        dotenv.env['SUPABASE_ANON_KEY']!,
  );
}

void _runApp() {
  runApp(
    // ProviderScope is the root of all Riverpod providers.
    const ProviderScope(child: GearStockApp()),
  );
}

/// Root application widget.
///
/// Uses [MaterialApp.router] wired to the [routerProvider] (go_router).
/// Auth state changes drive redirects — no manual [Navigator] calls anywhere.
class GearStockApp extends ConsumerWidget {
  const GearStockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(syncRunnerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'GearStock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) =>
          AppSplashOverlay(child: child ?? const SizedBox.shrink()),

      // i18n — en_IN primary locale, hi secondary.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en', 'IN'), Locale('hi')],
    );
  }
}
