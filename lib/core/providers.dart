import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/sync/data/sync_queue_repository.dart';
import 'providers/database_provider.dart';

/// Provides the initialized Supabase client.
/// [Supabase.initialize] must be called before this is read (done in main).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
  name: 'supabaseClient',
);

final authenticatedUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  final subscription = client.auth.onAuthStateChange.listen((state) {
    if (authUserChanged(userId, state.session?.user.id)) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(subscription.cancel);
  return userId;
}, name: 'authenticatedUserId');

/// Compatibility alias for the authenticated-account-scoped local database.
final driftDbProvider = appDatabaseProvider;

final syncQueueRepositoryProvider = Provider<SyncQueueRepository?>((ref) {
  final userId = ref.watch(authenticatedUserIdProvider);
  if (userId == null) return null;
  return SyncQueueRepository(ref.watch(appDatabaseProvider), userId);
}, name: 'syncQueueRepository');
