import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/app_database.dart';

class StockSyncService {
  StockSyncService(this._db, this._supabase);

  final AppDatabase _db;
  final SupabaseClient _supabase;

  Future<void> uploadMovementPayload(
    Map<String, dynamic> payload, {
    required String shopId,
  }) async {
    await _supabase.from('stock_movements').upsert(
      {...payload, 'shop_id': shopId},
      onConflict: 'id',
      ignoreDuplicates: true,
    );
  }

  Future<void> downloadMovements({required String shopId}) async {
    for (var offset = 0;; offset += 1000) {
      final rows = await _supabase
          .from('stock_movements')
          .select()
          .eq('shop_id', shopId)
          .order('id')
          .range(offset, offset + 999);
      for (final row in rows) {
        await _db.upsertMovement(
          StockMovementsTableCompanion.insert(
            id: row['id'] as String,
            productId: row['product_id'] as String,
            type: row['type'] as String,
            quantity: row['quantity'] as int,
            note: Value((row['note'] as String?) ?? ''),
            referenceNumber: Value((row['reference_number'] as String?) ?? ''),
            unitPrice: Value((row['unit_price'] as num?)?.toDouble() ?? 0),
            operatorName: Value((row['operator_name'] as String?) ?? ''),
            supplierId: Value(row['supplier_id'] as String?),
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
}

final stockSyncServiceProvider = Provider<StockSyncService>((ref) {
  return StockSyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(supabaseClientProvider),
  );
});
