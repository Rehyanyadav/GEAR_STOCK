import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';

String localDatabaseNameForUser(String? userId) {
  return 'gearstock_${userId ?? 'anonymous'}';
}

bool authUserChanged(String? currentUserId, String? nextUserId) {
  return currentUserId != nextUserId;
}

/// Account-scoped [AppDatabase]. Auth changes dispose and reopen a separate
/// local database so a previous account's cached records are not displayed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  final db = AppDatabase(databaseName: localDatabaseNameForUser(userId));
  final authSubscription = client.auth.onAuthStateChange.listen((state) {
    if (authUserChanged(userId, state.session?.user.id)) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(() {
    unawaited(authSubscription.cancel());
    unawaited(db.close());
  });
  return db;
});
