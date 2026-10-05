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
}) {
  return SyncQueueTableCompanion.insert(
    id: const Uuid().v4(),
    userId: userId,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    payload: jsonEncode(payload),
  );
}

class SyncQueueRepository {
  SyncQueueRepository(this._database, this.userId);

  final AppDatabase _database;
  final String userId;

  Future<void> enqueue(SyncQueueTableCompanion change) async {
    if (change.userId.value != userId) {
      throw ArgumentError('A sync queue row cannot be queued for another user.');
    }
    await _database.into(_database.syncQueueTable).insert(change);
  }

  Future<List<SyncQueueTableData>> allChanges() {
    return (_database.select(_database.syncQueueTable)
          ..where((row) => row.userId.equals(userId))
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
  }

  Future<List<SyncQueueTableData>> readyChanges() {
    final now = DateTime.now();
    return (_database.select(_database.syncQueueTable)
          ..where(
            (row) =>
                row.userId.equals(userId) &
                (row.nextAttemptAt.isNull() |
                    row.nextAttemptAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
  }

  Stream<List<SyncQueueTableData>> watchChanges() {
    return (_database.select(_database.syncQueueTable)
          ..where((row) => row.userId.equals(userId))
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .watch();
  }

  Future<void> acknowledge(String id) async {
    await (_database.delete(_database.syncQueueTable)
          ..where((row) => row.id.equals(id) & row.userId.equals(userId)))
        .go();
  }

  Future<void> defer(SyncQueueTableData change, Object error) async {
    final attempts = change.attempts + 1;
    final exponent = attempts.clamp(1, 8).toInt() - 1;
    final delaySeconds = (1 << exponent).clamp(1, 300).toInt();
    final safeError = error.runtimeType.toString();
    await (_database.update(_database.syncQueueTable)
          ..where((row) => row.id.equals(change.id) & row.userId.equals(userId)))
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
}
