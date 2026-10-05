import '../domain/auth_state.dart';

/// Repository interface for authentication operations.
/// The UI layer depends on this abstraction, never on Supabase directly.
abstract interface class AuthRepository {
  /// Returns the current auth state from the local session cache.
  /// Safe to call offline — Supabase SDK caches the last session on-device.
  Future<AuthState> currentSession();

  /// Attempts to sign in with [email] and [password].
  /// Throws a subtype of [AuthException] on failure.
  Future<AuthState> signIn({required String email, required String password});

  /// Signs out from Supabase and clears the local session cache.
  Future<void> signOut();

  /// Real-time stream of auth state changes (login, logout, token refresh).
  Stream<AuthState> get authStateChanges;
}

// ── Typed error hierarchy ──────────────────────────────────────────────────

/// Base class for all auth errors surfaced to the presentation layer.
sealed class AuthException implements Exception {
  const AuthException();
}

/// Credentials were rejected by Supabase (HTTP 400).
final class WrongCredentials extends AuthException {
  const WrongCredentials();
}

/// Device has no internet connectivity.
final class NoInternet extends AuthException {
  const NoInternet();
}

final class RateLimited extends AuthException {
  const RateLimited({required this.retryAfter});

  final Duration retryAfter;
}

/// Supabase returned a non-400 error or the request failed unexpectedly.
final class ServerError extends AuthException {
  const ServerError(this.message);

  final String message;
}
