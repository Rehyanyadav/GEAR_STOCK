import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/auth_notifier.dart';
import '../features/auth/presentation/login_screen.dart';
import '../screens/barcode_scanner_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../screens/products_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/stock_in_screen.dart';
import '../screens/stock_out_screen.dart';
import '../screens/suppliers_screen.dart';
import '../widgets/theme_mode_selector.dart';
import '../widgets/app_header.dart';

/// Provides the [GoRouter] instance.
/// Must be inside [ProviderScope] — watches [authNotifierProvider] for redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    observers: [_sentryNavigationObserver()],

    // ── Route guards ─────────────────────────────────────────────────────
    redirect: (context, state) {
      final authAsync = ref.read(authNotifierProvider);

      // Do nothing while session is still loading from cache.
      if (authAsync.isLoading) return null;

      final isAuthenticated = authAsync.valueOrNull is Authenticated;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isOnLogin) return '/login';
      if (isAuthenticated && isOnLogin) return '/home';
      return null;
    },

    routes: [
      // ── Auth ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Authenticated shell with bottom nav ───────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, routerState, shell) =>
            _AppShell(shell: shell, ref: ProviderScope.containerOf(context)),
        branches: [
          // ── Branch 0: Dashboard ───────────────────────────────────────
          StatefulShellBranch(
            observers: [_sentryNavigationObserver()],
            routes: [
              GoRoute(
                path: '/home',
                name: 'dashboard',
                builder: (context, state) {
                  return DashboardScreen(
                    onNavigateToStockIn: () => context.push('/stock-in'),
                    onNavigateToStockOut: () => context.push('/stock-out'),
                    onNavigateToProducts: () => context.go('/products'),
                  );
                },
              ),
            ],
          ),

          // ── Branch 1: Products ────────────────────────────────────────
          StatefulShellBranch(
            observers: [_sentryNavigationObserver()],
            routes: [
              GoRoute(
                path: '/products',
                name: 'products',
                builder: (context, state) {
                  return const ProductsScreen();
                },
              ),
            ],
          ),

          // ── Branch 2: Reports ─────────────────────────────────────────
          StatefulShellBranch(
            observers: [_sentryNavigationObserver()],
            routes: [
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (context, state) {
                  return const ReportsScreen();
                },
              ),
            ],
          ),
        ],
      ),

      // ── Pushed routes (not bottom-nav tabs) ───────────────────────────
      GoRoute(
        path: '/stock-in',
        name: 'stockIn',
        builder: (context, state) {
          return const StockInScreen();
        },
      ),
      GoRoute(
        path: '/stock-out',
        name: 'stockOut',
        builder: (context, state) {
          return const StockOutScreen();
        },
      ),
      GoRoute(
        path: '/barcode',
        name: 'barcode',
        builder: (context, state) {
          return const BarcodeScannerScreen();
        },
      ),
      GoRoute(
        path: '/suppliers',
        name: 'suppliers',
        builder: (context, state) {
          return const SuppliersScreen();
        },
      ),
    ],
  );

  ref.listen(authNotifierProvider, (previous, next) => router.refresh());

  return router;
}, name: 'router');

SentryNavigatorObserver _sentryNavigationObserver() {
  return SentryNavigatorObserver(
    routeNameExtractor: (settings) =>
        settings == null ? null : RouteSettings(name: settings.name),
  );
}

// ── Shell scaffold ──────────────────────────────────────────────────────────
// Replicates the original MainShell UI (app bar, custom bottom nav, center FAB,
// stock sheet, profile modal) wired to go_router instead of setState / IndexedStack.
//
// SHIM: will be replaced by a full ConsumerStatefulWidget during shell migration.

class _AppShell extends ConsumerStatefulWidget {
  const _AppShell({required this.shell, required this.ref});

  final StatefulNavigationShell shell;
  // ignore: unused_field — carried for future ref access in sub-methods
  final ProviderContainer ref;

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  // ── Navigation helpers ─────────────────────────────────────────────────

  String get _subtitle => switch (widget.shell.currentIndex) {
    0 => 'Workshop Dashboard',
    1 => 'Inventory Catalog',
    2 => 'Reports & Audits',
    _ => 'Workshop OS',
  };

  void _onTab(int index) => widget.shell.goBranch(index);

  // ── Stock action sheet ─────────────────────────────────────────────────

  void _showStockActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Floor Operations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select operation to log into workshop database',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 20),
              _stockTile(
                ctx: ctx,
                icon: Icons.archive,
                color: Theme.of(context).colorScheme.primary,
                title: 'Stock In: Receive Parts',
                subtitle: 'Log inbound vendor purchase orders & restock parts',
                route: '/stock-in',
              ),
              const SizedBox(height: 12),
              _stockTile(
                ctx: ctx,
                icon: Icons.build,
                color: Theme.of(context).colorScheme.primaryContainer,
                title: 'Stock Out: Issue Parts',
                subtitle:
                    'Issue spares for repair job cards or counter walk-ins',
                route: '/stock-out',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockTile({
    required BuildContext ctx,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String route,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onPrimary,
        size: 20,
      ),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
    onTap: () {
      Navigator.pop(ctx);
      context.push(route);
    },
  );

  // ── Profile / logout modal ─────────────────────────────────────────────

  void _showProfileModal() {
    final authAsync = ref.read(authNotifierProvider);
    final email = authAsync.valueOrNull is Authenticated
        ? (authAsync.valueOrNull as Authenticated).email
        : 'user@example.com';
    final name = email.split('@').first;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/images/profile_avatar.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.person, size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                email,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Shop Owner • GearStock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.dark_mode_outlined,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                title: const Text('Appearance'),
                subtitle: const Text('Choose system, light, or dark mode'),
                trailing: const ThemeModeSelector(),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.storefront,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Suppliers & Vendors Directory'),
                subtitle: const Text('Manage parts distributors'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/suppliers');
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: const Text('About GearStock'),
                subtitle: const Text('Version 1.0.0 • Offline-Ready'),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(authNotifierProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.shell.currentIndex;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppHeader(
        title: 'GearStock',
        subtitle: _subtitle,
        onProfileTap: _showProfileModal,
        onSearchTap: () => _onTab(1), // jump to Products
      ),
      body: widget.shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Home',
                  currentIndex: currentIndex,
                ),
                _navItem(
                  index: 1,
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  label: 'Products',
                  currentIndex: currentIndex,
                ),

                // Centre FAB — barcode scanner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => context.push('/barcode'),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(90),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 26,
                      ),
                    ),
                  ),
                ),

                // Stock sheet button
                InkWell(
                  onTap: _showStockActionSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swap_vert,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 24,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Stock',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                _navItem(
                  index: 2,
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Reports',
                  currentIndex: currentIndex,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int currentIndex,
  }) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => _onTab(index),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
