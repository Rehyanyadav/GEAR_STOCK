import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/app_database.dart';

class SuppliersSyncService {
  SuppliersSyncService(this._db, this._supabase);

  final AppDatabase _db;
  final SupabaseClient _supabase;

  Future<void> downloadSuppliers({required String shopId}) async {
    for (var offset = 0;; offset += 1000) {
      final rows = await _supabase
          .from('suppliers')
          .select()
          .eq('shop_id', shopId)
          .order('id')
          .range(offset, offset + 999);
      for (final row in rows) {
        await _db.upsertSupplier(
          SuppliersTableCompanion.insert(
            id: row['id'] as String,
            name: row['name'] as String,
            contactPerson: Value((row['contact_person'] as String?) ?? ''),
            phone: Value((row['phone'] as String?) ?? ''),
            email: Value((row['email'] as String?) ?? ''),
            city: Value((row['city'] as String?) ?? ''),
            gstNumber: Value(row['gst_number'] as String?),
            leadTimeDays: Value((row['lead_time_days'] as int?) ?? 0),
            rating: Value((row['rating'] as num?)?.toDouble() ?? 0),
            isDeleted: Value((row['is_deleted'] as bool?) ?? false),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
      }
      if (rows.length < 1000) break;
    }
  }

  Future<void> uploadSupplierPayload(
    Map<String, dynamic> payload, {
    required String shopId,
  }) async {
    await _supabase
        .from('suppliers')
        .upsert({...payload, 'shop_id': shopId}, onConflict: 'id');
  }
}

final suppliersSyncServiceProvider = Provider<SuppliersSyncService>((ref) {
  return SuppliersSyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(supabaseClientProvider),
  );
});
