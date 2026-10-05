/// Sealed union representing all possible authentication states.
sealed class AuthState {
  const AuthState();
}

/// No active Supabase session exists on this device.
final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// A valid Supabase session exists (may be locally cached while offline).
final class Authenticated extends AuthState {
  const Authenticated({required this.userId, required this.email});

  final String userId;
  final String email;
}
