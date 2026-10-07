import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/app_database.dart';

const _movementCursorOverlap = Duration(minutes: 5);
const _movementCursorVersion = 2;

class StockSyncService {
  StockSyncService(this._db, this._supabase);

  final AppDatabase _db;
  final SupabaseClient _supabase;

  Future<void> uploadMovementPayload(
    Map<String, dynamic> payload, {
    required String shopId,
  }) async {
    await _supabase
        .from('stock_movements')
        .upsert(
          {...payload, 'shop_id': shopId},
          onConflict: 'id',
          ignoreDuplicates: true,
        );
  }

  Future<void> downloadMovements({required String shopId}) async {
    final cursorId = 'stock-movements:v$_movementCursorVersion:$shopId';
    while (true) {
      final cursor = await _db.getSyncCursor(cursorId);
      final rows = await _fetchMovementPage(
        shopId: shopId,
        offset: 0,
        cursor: cursor,
      );
      if (rows.isEmpty) break;

      final movements = rows.map(_movementFromRow).toList();
      final lastRow = rows.last;
      await _db.importMovementsAtomically(
        movements,
        cursor: SyncCursorsTableCompanion.insert(
          id: cursorId,
          syncedAt: lastRow['synced_at'] as String,
          lastId: lastRow['id'] as String,
        ),
      );
      if (rows.length < 1000) break;
    }
    final cursor = await _db.getSyncCursor(cursorId);
    if (cursor != null) {
      await _downloadRecentOverlap(shopId: shopId, cursor: cursor);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMovementPage({
    required String shopId,
    required int offset,
    SyncCursorsTableData? cursor,
    String? since,
  }) {
    var query = _supabase
        .from('stock_movements')
        .select()
        .eq('shop_id', shopId);
    if (cursor != null) {
      query = query.or(
        'synced_at.gt.${cursor.syncedAt},'
        'and(synced_at.eq.${cursor.syncedAt},id.gt.${cursor.lastId})',
      );
    } else if (since != null) {
      query = query.gte('synced_at', since);
    }
    return query
        .order('synced_at', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + 999);
  }

  Future<void> _downloadRecentOverlap({
    required String shopId,
    required SyncCursorsTableData cursor,
  }) async {
    final since = DateTime.parse(
      cursor.syncedAt,
    ).toUtc().subtract(_movementCursorOverlap).toIso8601String();
    for (var offset = 0; ; offset += 1000) {
      final rows = await _fetchMovementPage(
        shopId: shopId,
        offset: offset,
        since: since,
      );
      if (rows.isEmpty) return;
      await _db.importMovementsAtomically(rows.map(_movementFromRow).toList());
      if (rows.length < 1000) return;
    }
  }

  StockMovementsTableCompanion _movementFromRow(Map<String, dynamic> row) {
    return StockMovementsTableCompanion.insert(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      type: row['type'] as String,
      quantity: row['quantity'] as int,
      stockAfter: Value(row['stock_after'] as int?),
      note: Value((row['note'] as String?) ?? ''),
      referenceNumber: Value((row['reference_number'] as String?) ?? ''),
      unitPrice: Value((row['unit_price'] as num?)?.toDouble() ?? 0),
      operatorName: Value((row['operator_name'] as String?) ?? ''),
      supplierId: Value(row['supplier_id'] as String?),
      createdAt: Value(
        DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
      ),
    );
  }
}

final stockSyncServiceProvider = Provider<StockSyncService>((ref) {
  return StockSyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(supabaseClientProvider),
  );
});
