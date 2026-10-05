import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repo.dart';
import '../domain/auth_state.dart';
import '../../../core/providers.dart';

/// Provides the [AuthRepository] implementation.
/// Override in tests to inject a [FakeAuthRepository].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
  name: 'authRepository',
);

/// Stream of [AuthState] changes from Supabase (login, logout, token refresh).
/// Private — consumed only by [AuthNotifier].
final _authChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
  name: '_authChanges',
);

/// The primary auth notifier.
/// go_router's [redirect] callback watches this to enforce route guards.
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // 1. Restore existing session from Supabase's encrypted local cache.
    //    This works offline — no network call needed.
    final repo = ref.watch(authRepositoryProvider);
    final initial = await repo.currentSession();

    // 2. Keep state in sync with server-side auth events.
    ref.listen(_authChangesProvider, (_, next) {
      next.whenData((authState) => state = AsyncData(authState));
    });

    return initial;
  }

  /// Signs in with email and password.
  /// Sets state to [AsyncLoading] during the call, then [AsyncData] or
  /// [AsyncError] depending on the outcome.
  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(
      () => repo.signIn(email: email, password: password),
    );
  }

  /// Signs out and clears the local session.
  Future<void> logout() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(Unauthenticated());
  }
}
