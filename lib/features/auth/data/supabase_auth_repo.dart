import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../domain/auth_state.dart';
import 'auth_repository.dart';

/// Supabase implementation of [AuthRepository].
///
/// All Supabase SDK calls are contained here; the rest of the app never
/// imports supabase_flutter directly. The import is prefixed because this
/// file also declares its own domain-level [AuthException] hierarchy.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<AuthState> currentSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return const Unauthenticated();
    return Authenticated(
      userId: session.user.id,
      email: session.user.email ?? '',
    );
  }

  @override
  Future<AuthState> signIn({
    required String email,
    required String password,
  }) async {
    // Detect offline state before hitting the network so the user gets a
    // clear message instead of a generic server error.
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const NoInternet();
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw const WrongCredentials();
      return Authenticated(userId: user.id, email: user.email ?? email);
    } on supabase.AuthException catch (e) {
      // Supabase rejects bad credentials with HTTP 400 / invalid_credentials.
      if (e.statusCode == '400' || e.code == 'invalid_credentials') {
        throw const WrongCredentials();
      }
      if (e.statusCode == '429' ||
          (e.code?.toLowerCase().contains('rate') ?? false) ||
          e.message.toLowerCase().contains('too many requests')) {
        final seconds = RegExp(
          r'(\d+)\s+seconds?',
          caseSensitive: false,
        ).firstMatch(e.message)?.group(1);
        final retrySeconds = int.tryParse(seconds ?? '') ?? 30;
        throw RateLimited(
          retryAfter: Duration(seconds: retrySeconds.clamp(1, 300).toInt()),
        );
      }
      throw ServerError(e.message);
    } catch (_) {
      // Network-level or otherwise unexpected failures.
      throw const ServerError('Unexpected error. Please try again.');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) {
        final user = event.session?.user;
        if (user == null) return const Unauthenticated();
        return Authenticated(userId: user.id, email: user.email ?? '');
      });
}
