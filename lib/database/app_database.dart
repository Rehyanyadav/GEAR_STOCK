import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/categories_table.dart';
import 'tables/products_table.dart';
import 'tables/stock_movements_table.dart';
import 'tables/suppliers_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/sync_cursors_table.dart';

export 'tables/categories_table.dart';
export 'tables/products_table.dart';
export 'tables/stock_movements_table.dart';
export 'tables/suppliers_table.dart';
export 'tables/sync_queue_table.dart';
export 'tables/sync_cursors_table.dart';

part 'app_database.g.dart';

/// Local cache of the authenticated Supabase user profile.
class UsersCache extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get lastSynced => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    UsersCache,
    CategoriesTable,
    ProductsTable,
    SuppliersTable,
    StockMovementsTable,
    SyncQueueTable,
    SyncCursorsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({String databaseName = 'gearstock'})
    : super(_openConnection(databaseName));

  /// Constructor used in tests — supply any [QueryExecutor]
  /// (typically `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _applyPragmas();
      await _createStockTrigger();
      await _createStockIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 → v2: add products, categories, suppliers, stock_movements
        await m.createTable(categoriesTable);
        await m.createTable(productsTable);
        await m.createTable(suppliersTable);
        await m.createTable(stockMovementsTable);
      }
      if (from < 3) {
        await customStatement(
          "UPDATE products SET updated_at = "
          "CAST(strftime('%s', updated_at) AS INTEGER) * 1000 "
          "WHERE typeof(updated_at) = 'text' "
          "AND strftime('%s', updated_at) IS NOT NULL",
        );
      }
      if (from < 4) {
        await m.createTable(syncQueueTable);
      }
      if (from >= 2 && from < 5) {
        await m.addColumn(stockMovementsTable, stockMovementsTable.stockAfter);
        await m.addColumn(
          stockMovementsTable,
          stockMovementsTable.applyStockEffect,
        );
      }
      if (from < 5) {
        await _createStockTrigger();
      }
      if (from < 6) {
        await m.createTable(syncCursorsTable);
        await _createStockIndexes();
      }
      if (from < 7) {
        await m.addColumn(syncQueueTable, syncQueueTable.status);
      }
    },
    beforeOpen: (details) async {
      await _applyPragmas();
    },
  );

  Future<void> _applyPragmas() async {
    await customStatement('PRAGMA foreign_keys = ON');
    await customStatement('PRAGMA journal_mode = WAL');
  }

  /// SQLite trigger that automatically adjusts [ProductsTable.currentStock]
  /// whenever a row is inserted into [StockMovementsTable].
  /// - type = 'IN'  → currentStock + quantity
  /// - type = 'OUT' → currentStock - quantity (clamped to 0 via MAX)
  Future<void> _createStockTrigger() async {
    await customStatement('DROP TRIGGER IF EXISTS trg_update_stock');
    await customStatement('''
      CREATE TRIGGER trg_update_stock
      AFTER INSERT ON stock_movements
      WHEN NEW.apply_stock_effect = 1
      BEGIN
        UPDATE products
        SET current_stock = CASE
          WHEN NEW.type = 'IN'  THEN current_stock + NEW.quantity
          WHEN NEW.type = 'OUT' THEN MAX(0, current_stock - NEW.quantity)
          WHEN NEW.type = 'ADJUSTMENT' THEN NEW.stock_after
          ELSE current_stock
        END,
        updated_at = CAST(strftime('%s', 'now') AS INTEGER) * 1000
        WHERE id = NEW.product_id;
      END;
    ''');
  }

  Future<void> _createStockIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS stock_movements_product_created_at_idx '
      'ON stock_movements (product_id, created_at)',
    );
  }

  // ── Products ──────────────────────────────────────────────────────────────

  /// Watch all non-deleted products ordered by name.
  Stream<List<ProductsTableData>> watchAllProducts() {
    return (select(productsTable)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<ProductsTableData>> getAllProducts() {
    return (select(productsTable)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<ProductsTableData?> getProductById(String id) {
    return (select(
      productsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<ProductsTableData?> getProductByBarcode(String barcode) {
    return (select(productsTable)
          ..where((t) => t.barcode.equals(barcode) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<void> updateStockSnapshots(Map<String, int> stockByProductId) async {
    for (final stock in stockByProductId.values) {
      if (stock < 0) {
        throw ArgumentError.value(
          stock,
          'stockByProductId',
          'Stock snapshots cannot be negative.',
        );
      }
    }
    await transaction(() async {
      for (final entry in stockByProductId.entries) {
        await (update(productsTable)
              ..where((product) => product.id.equals(entry.key)))
            .write(ProductsTableCompanion(currentStock: Value(entry.value)));
      }
    });
  }

  Future<void> upsertProduct(ProductsTableCompanion c) async {
    await into(productsTable).insertOnConflictUpdate(c);
  }

  Future<void> saveProduct({
    required ProductsTableCompanion product,
    CategoriesTableCompanion? category,
    SyncQueueTableCompanion? queuedChange,
  }) async {
    await saveProductAndMovements(
      product: product,
      category: category,
      queuedChange: queuedChange,
    );
  }

  Future<void> saveProductAndMovements({
    required ProductsTableCompanion product,
    CategoriesTableCompanion? category,
    SyncQueueTableCompanion? queuedChange,
    List<StockMovementsTableCompanion> movements = const [],
    List<SyncQueueTableCompanion> queuedMovementChanges = const [],
  }) async {
    if (queuedMovementChanges.isNotEmpty &&
        queuedMovementChanges.length != movements.length) {
      throw ArgumentError(
        'Each movement must have exactly one corresponding sync queue row.',
      );
    }
    await transaction(() async {
      if (category != null) {
        await into(categoriesTable).insertOnConflictUpdate(category);
      }
      await into(productsTable).insertOnConflictUpdate(product);
      if (queuedChange != null) {
        await into(syncQueueTable).insert(queuedChange);
      }
      await _insertMovementsWithinTransaction(
        movements,
        queuedChanges: queuedMovementChanges,
      );
    });
  }

  Future<void> deleteProduct(
    String id, {
    SyncQueueTableCompanion? queuedChange,
  }) async {
    await transaction(() async {
      await (delete(syncQueueTable)..where(
            (entry) =>
                entry.entityType.equals('product') & entry.entityId.equals(id),
          ))
          .go();
      await (update(productsTable)..where((product) => product.id.equals(id)))
          .write(const ProductsTableCompanion(isDeleted: Value(true)));
      if (queuedChange != null) {
        await into(syncQueueTable).insert(queuedChange);
      }
    });
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Stream<List<CategoriesTableData>> watchAllCategories() {
    return (select(
      categoriesTable,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<void> upsertCategory(CategoriesTableCompanion c) async {
    await into(categoriesTable).insertOnConflictUpdate(c);
  }

  Future<void> saveCategory({
    required CategoriesTableCompanion category,
    SyncQueueTableCompanion? queuedChange,
  }) async {
    await transaction(() async {
      await into(categoriesTable).insertOnConflictUpdate(category);
      if (queuedChange != null) {
        await into(syncQueueTable).insert(queuedChange);
      }
    });
  }

  Future<void> deleteCategory(
    String name, {
    SyncQueueTableCompanion? queuedChange,
  }) async {
    await transaction(() async {
      await (update(productsTable)
            ..where((product) => product.categoryId.equals(name)))
          .write(const ProductsTableCompanion(categoryId: Value(null)));
      await (delete(
        categoriesTable,
      )..where((category) => category.id.equals(name))).go();
      if (queuedChange != null) {
        await into(syncQueueTable).insert(queuedChange);
      }
    });
  }

  // ── Suppliers ─────────────────────────────────────────────────────────────

  Stream<List<SuppliersTableData>> watchAllSuppliers() {
    return (select(suppliersTable)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<SuppliersTableData?> getSupplierById(String id) {
    return (select(
      suppliersTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertSupplier(SuppliersTableCompanion c) async {
    await into(suppliersTable).insertOnConflictUpdate(c);
  }

  Future<void> saveSupplier({
    required SuppliersTableCompanion supplier,
    SyncQueueTableCompanion? queuedChange,
  }) async {
    await transaction(() async {
      await into(suppliersTable).insertOnConflictUpdate(supplier);
      if (queuedChange != null) {
        await into(syncQueueTable).insert(queuedChange);
      }
    });
  }

  Future<void> softDeleteSupplier(
    String id, {
    SyncQueueTableCompanion? queuedChange,
  }) async {
    await transaction(() async {
      await (update(suppliersTable)..where((t) => t.id.equals(id))).write(
        SuppliersTableCompanion(isDeleted: const Value(true)),
      );
      if (queuedChange != null) {
        await into(syncQueueTable).insert(queuedChange);
      }
    });
  }

  // ── Stock Movements ───────────────────────────────────────────────────────

  /// Watch all movements for a product, newest first.
  Stream<List<StockMovementsTableData>> watchMovementsForProduct(
    String productId,
  ) {
    return (select(stockMovementsTable)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Watch recent movements across all products (for Dashboard).
  Stream<List<StockMovementsTableData>> watchRecentMovements({int limit = 20}) {
    return (select(stockMovementsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> insertMovement(StockMovementsTableCompanion c) async {
    await into(
      stockMovementsTable,
    ).insert(c.copyWith(applyStockEffect: const Value(true)));
    // The SQLite trigger (trg_update_stock) automatically updates currentStock.
  }

  Future<void> upsertMovement(StockMovementsTableCompanion c) async {
    await into(stockMovementsTable).insert(
      c.copyWith(applyStockEffect: const Value(false)),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> importMovementsAtomically(
    List<StockMovementsTableCompanion> movements, {
    SyncCursorsTableCompanion? cursor,
  }) async {
    await transaction(() async {
      for (final movement in movements) {
        await into(stockMovementsTable).insert(
          movement.copyWith(applyStockEffect: const Value(false)),
          mode: InsertMode.insertOrIgnore,
        );
      }
      if (cursor != null) {
        await into(syncCursorsTable).insertOnConflictUpdate(cursor);
      }
    });
  }

  Future<SyncCursorsTableData?> getSyncCursor(String id) {
    return (select(
      syncCursorsTable,
    )..where((cursor) => cursor.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertMovementsAtomically(
    List<StockMovementsTableCompanion> movements, {
    List<SyncQueueTableCompanion> queuedChanges = const [],
  }) async {
    if (queuedChanges.isNotEmpty && queuedChanges.length != movements.length) {
      throw ArgumentError(
        'Each movement must have exactly one corresponding sync queue row.',
      );
    }
    await transaction(() async {
      await _insertMovementsWithinTransaction(
        movements,
        queuedChanges: queuedChanges,
      );
    });
  }

  Future<void> _insertMovementsWithinTransaction(
    List<StockMovementsTableCompanion> movements, {
    List<SyncQueueTableCompanion> queuedChanges = const [],
  }) async {
    if (queuedChanges.isNotEmpty && queuedChanges.length != movements.length) {
      throw ArgumentError(
        'Each movement must have exactly one corresponding sync queue row.',
      );
    }
    for (var index = 0; index < movements.length; index++) {
      final movement = movements[index];
      final quantity = movement.quantity.value;
      final type = movement.type.value;
      final stockAfter = movement.stockAfter.value;
      if (type == 'ADJUSTMENT' ? quantity == 0 : quantity <= 0) {
        throw ArgumentError.value(
          quantity,
          'quantity',
          type == 'ADJUSTMENT'
              ? 'An adjustment delta cannot be zero.'
              : 'Must be positive.',
        );
      }
      if (type == 'ADJUSTMENT' && (stockAfter == null || stockAfter < 0)) {
        throw ArgumentError.value(
          stockAfter,
          'stockAfter',
          'An adjustment must set a nonnegative stock count.',
        );
      }
      if (type != 'ADJUSTMENT' && stockAfter != null) {
        throw ArgumentError.value(
          stockAfter,
          'stockAfter',
          'Only an adjustment can set stockAfter.',
        );
      }

      final product = await getProductById(movement.productId.value);
      if (product == null || product.isDeleted) {
        throw StateError('Product ${movement.productId.value} is unavailable.');
      }
      if (type == 'OUT' && quantity > product.currentStock) {
        throw StateError(
          'Cannot remove $quantity units — only ${product.currentStock} in stock.',
        );
      }
      if (type != 'IN' && type != 'OUT' && type != 'ADJUSTMENT') {
        throw ArgumentError.value(
          type,
          'type',
          'Must be IN, OUT, or ADJUSTMENT.',
        );
      }

      await into(
        stockMovementsTable,
      ).insert(movement.copyWith(applyStockEffect: const Value(true)));
      if (queuedChanges.isNotEmpty) {
        await into(syncQueueTable).insert(queuedChanges[index]);
      }
    }
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  /// Total value of all current (non-deleted) stock: SUM(currentStock * costPrice).
  Future<double> getTotalStockValue() async {
    final result = await customSelect(
      'SELECT IFNULL(SUM(current_stock * cost_price), 0) AS total '
      'FROM products WHERE is_deleted = 0',
      readsFrom: {productsTable},
    ).getSingle();
    return result.read<double>('total');
  }

  /// Products where currentStock ≤ minStock.
  Stream<List<ProductsTableData>> watchLowStockProducts() {
    return (select(productsTable)
          ..where(
            (t) =>
                t.isDeleted.equals(false) &
                const CustomExpression<bool>('current_stock <= min_stock'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.currentStock)]))
        .watch();
  }

  /// Stock movements within a date range, newest first.
  Future<List<StockMovementsTableData>> getMovementsInRange(
    DateTime from,
    DateTime to,
  ) {
    return (select(stockMovementsTable)
          ..where(
            (t) =>
                t.createdAt.isBiggerOrEqualValue(from) &
                t.createdAt.isSmallerOrEqualValue(to),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }
}

QueryExecutor _openConnection(String databaseName) {
  return driftDatabase(name: databaseName);
}
