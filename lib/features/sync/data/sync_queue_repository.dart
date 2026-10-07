import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart';

SyncQueueTableCompanion createSyncQueueEntry({
  required String userId,
  required String entityType,
  required String entityId,
  required String operation,
  required Map<String, Object?> payload,
  DateTime? createdAt,
}) {
  return SyncQueueTableCompanion.insert(
    id: const Uuid().v4(),
    userId: userId,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    payload: jsonEncode(payload),
    createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
  );
}

class SyncQueueRepository {
  SyncQueueRepository(this._database, this.userId);

  final AppDatabase _database;
  final String userId;

  Future<void> enqueue(SyncQueueTableCompanion change) async {
    if (change.userId.value != userId) {
      throw ArgumentError(
        'A sync queue row cannot be queued for another user.',
      );
    }
    await _database.into(_database.syncQueueTable).insert(change);
  }

  Future<List<SyncQueueTableData>> allChanges() {
    return (_database.select(_database.syncQueueTable)
          ..where((row) => row.userId.equals(userId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.createdAt),
            (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
          ]))
        .get();
  }

  Future<List<SyncQueueTableData>> readyChanges() {
    final now = DateTime.now();
    return (_database.select(_database.syncQueueTable)
          ..where(
            (row) =>
                row.userId.equals(userId) &
                row.status.equals('pending') &
                (row.nextAttemptAt.isNull() |
                    row.nextAttemptAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.createdAt),
            (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
          ]))
        .get();
  }

  Stream<List<SyncQueueTableData>> watchChanges() {
    return (_database.select(_database.syncQueueTable)
          ..where((row) => row.userId.equals(userId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.createdAt),
            (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
          ]))
        .watch();
  }

  Future<void> acknowledge(String id) async {
    await (_database.delete(
      _database.syncQueueTable,
    )..where((row) => row.id.equals(id) & row.userId.equals(userId))).go();
  }

  Future<void> defer(SyncQueueTableData change, Object error) async {
    final attempts = change.attempts + 1;
    final exponent = attempts.clamp(1, 8).toInt() - 1;
    final delaySeconds = (1 << exponent).clamp(1, 300).toInt();
    final safeError = error.runtimeType.toString();
    await (_database.update(
          _database.syncQueueTable,
        )..where((row) => row.id.equals(change.id) & row.userId.equals(userId)))
        .write(
          SyncQueueTableCompanion(
            attempts: Value(attempts),
            nextAttemptAt: Value(
              DateTime.now().add(Duration(seconds: delaySeconds)),
            ),
            lastError: Value(safeError),
          ),
        );
  }

  Future<void> markConflict(
    SyncQueueTableData change, {
    required String message,
  }) async {
    await (_database.update(
          _database.syncQueueTable,
        )..where((row) => row.id.equals(change.id) & row.userId.equals(userId)))
        .write(
          SyncQueueTableCompanion(
            status: const Value('conflict'),
            nextAttemptAt: const Value(null),
            lastError: Value(message),
          ),
        );
  }

  Future<void> resolveStockConflictsForProduct(String productId) async {
    await _database.transaction(() async {
      final conflicts =
          await (_database.select(_database.syncQueueTable)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.entityType.equals('stock_movement') &
                    row.status.equals('conflict'),
              ))
              .get();
      for (final conflict in conflicts) {
        final payload = jsonDecode(conflict.payload);
        if (payload is Map && payload['product_id'] == productId) {
          await (_database.delete(_database.syncQueueTable)..where(
                (row) => row.id.equals(conflict.id) & row.userId.equals(userId),
              ))
              .go();
        }
      }
    });
  }
}
