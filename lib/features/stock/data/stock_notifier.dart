import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/app_database.dart';
import '../../sync/data/sync_queue_repository.dart';
import '../../products/data/products_notifier.dart';
import '../../../models/stock_movement.dart';

// ── Mapper ────────────────────────────────────────────────────────────────────

StockMovement _toMovement(StockMovementsTableData row) => StockMovement(
  id: row.id,
  type: switch (row.type) {
    'IN' => StockMovementType.inbound,
    'OUT' => StockMovementType.outboundSale,
    'ADJUSTMENT' => StockMovementType.adjustment,
    _ => throw StateError('Unsupported stock movement type "${row.type}".'),
  },
  referenceNumber: row.referenceNumber,
  productId: row.productId,
  productName: '', // enriched in UI layer via productsProvider
  productSku: '',
  quantity: row.quantity,
  unitPrice: row.unitPrice,
  timestamp: row.createdAt,
  notes: row.note,
  operatorName: row.operatorName,
);

class StockInEntry {
  const StockInEntry({
    required this.productId,
    required this.quantity,
    this.note = '',
    this.referenceNumber = '',
    this.unitPrice = 0,
    this.supplierId,
    this.operatorName = '',
  });

  final String productId;
  final int quantity;
  final String note;
  final String referenceNumber;
  final double unitPrice;
  final String? supplierId;
  final String operatorName;
}

class StockOutEntry {
  const StockOutEntry({
    required this.productId,
    required this.quantity,
    this.note = '',
    this.referenceNumber = '',
    this.unitPrice = 0,
    this.operatorName = '',
  });

  final String productId;
  final int quantity;
  final String note;
  final String referenceNumber;
  final double unitPrice;
  final String operatorName;
}

// ── AsyncNotifier ──────────────────────────────────────────────────────────────

/// State: recent movements (across all products) for the Dashboard feed.
class StockNotifier extends AsyncNotifier<List<StockMovement>> {
  late AppDatabase _db;
  String? _userId;

  @override
  Future<List<StockMovement>> build() async {
    _db = ref.watch(appDatabaseProvider);
    _userId = ref.watch(authenticatedUserIdProvider);
    final sub = _db.watchRecentMovements().listen((rows) {
      state = AsyncData(rows.map(_toMovement).toList());
    });
    ref.onDispose(sub.cancel);
    return _db.watchRecentMovements().first.then(
      (r) => r.map(_toMovement).toList(),
    );
  }

  /// Records a stock-in movement.
  /// The SQLite trigger automatically increments [products.currentStock].
  Future<void> addStockIn({
    required String productId,
    required int quantity,
    String note = '',
    String referenceNumber = '',
    double unitPrice = 0,
    String? supplierId,
    String operatorName = '',
  }) async {
    await addStockInBatch([
      StockInEntry(
        productId: productId,
        quantity: quantity,
        note: note,
        referenceNumber: referenceNumber,
        unitPrice: unitPrice,
        supplierId: supplierId,
        operatorName: operatorName,
      ),
    ]);
  }

  Future<void> addStockInBatch(List<StockInEntry> entries) async {
    if (entries.isEmpty) {
      throw ArgumentError.value(entries, 'entries', 'Must not be empty.');
    }
    final movements = <StockMovementsTableCompanion>[];
    final queueEntries = <SyncQueueTableCompanion>[];
    for (final entry in entries) {
      final id = const Uuid().v4();
      final createdAt = DateTime.now();
      movements.add(
        StockMovementsTableCompanion.insert(
          id: id,
          productId: entry.productId,
          type: 'IN',
          quantity: entry.quantity,
          note: Value(entry.note),
          referenceNumber: Value(entry.referenceNumber),
          unitPrice: Value(entry.unitPrice),
          supplierId: Value(entry.supplierId),
          operatorName: Value(entry.operatorName),
          createdAt: Value(createdAt),
        ),
      );
      if (_userId != null) {
        queueEntries.add(
          createSyncQueueEntry(
            userId: _userId!,
            entityType: 'stock_movement',
            entityId: id,
            operation: 'insert',
            createdAt: createdAt,
            payload: {
              'id': id,
              'product_id': entry.productId,
              'type': 'IN',
              'quantity': entry.quantity,
              'note': entry.note,
              'reference_number': entry.referenceNumber,
              'unit_price': entry.unitPrice,
              'supplier_id': entry.supplierId,
              'operator_name': entry.operatorName,
              'created_at': createdAt.toIso8601String(),
            },
          ),
        );
      }
    }
    await _db.insertMovementsAtomically(movements, queuedChanges: queueEntries);
    await ref.read(productsProvider.notifier).refreshFromDatabase();
  }

  /// Records a stock-out movement.
  /// Throws [StateError] if [quantity] > current stock to prevent going negative.
  Future<void> addStockOut({
    required String productId,
    required int quantity,
    String note = '',
    String referenceNumber = '',
    double unitPrice = 0,
    String operatorName = '',
  }) async {
    await addStockOutBatch([
      StockOutEntry(
        productId: productId,
        quantity: quantity,
        note: note,
        referenceNumber: referenceNumber,
        unitPrice: unitPrice,
        operatorName: operatorName,
      ),
    ]);
  }

  Future<void> addStockOutBatch(List<StockOutEntry> entries) async {
    if (entries.isEmpty) {
      throw ArgumentError.value(entries, 'entries', 'Must not be empty.');
    }
    final movements = <StockMovementsTableCompanion>[];
    final queueEntries = <SyncQueueTableCompanion>[];
    for (final entry in entries) {
      final id = const Uuid().v4();
      final createdAt = DateTime.now();
      movements.add(
        StockMovementsTableCompanion.insert(
          id: id,
          productId: entry.productId,
          type: 'OUT',
          quantity: entry.quantity,
          note: Value(entry.note),
          referenceNumber: Value(entry.referenceNumber),
          unitPrice: Value(entry.unitPrice),
          operatorName: Value(entry.operatorName),
          createdAt: Value(createdAt),
        ),
      );
      if (_userId != null) {
        queueEntries.add(
          createSyncQueueEntry(
            userId: _userId!,
            entityType: 'stock_movement',
            entityId: id,
            operation: 'insert',
            createdAt: createdAt,
            payload: {
              'id': id,
              'product_id': entry.productId,
              'type': 'OUT',
              'quantity': entry.quantity,
              'note': entry.note,
              'reference_number': entry.referenceNumber,
              'unit_price': entry.unitPrice,
              'operator_name': entry.operatorName,
              'created_at': createdAt.toIso8601String(),
            },
          ),
        );
      }
    }
    await _db.insertMovementsAtomically(movements, queuedChanges: queueEntries);
    await ref.read(productsProvider.notifier).refreshFromDatabase();
  }
}

final stockProvider = AsyncNotifierProvider<StockNotifier, List<StockMovement>>(
  StockNotifier.new,
);
