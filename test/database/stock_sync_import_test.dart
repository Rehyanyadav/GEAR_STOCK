import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'imported movement history does not change the downloaded stock total',
    () async {
      await database.upsertProduct(
        ProductsTableCompanion.insert(
          id: 'product',
          sku: 'SKU-1',
          name: 'Brake pads',
          costPrice: 10,
          sellingPrice: 15,
          currentStock: const Value(5),
        ),
      );

      final movement = StockMovementsTableCompanion.insert(
        id: 'remote-movement',
        productId: 'product',
        type: 'IN',
        quantity: 4,
      );
      await database.importMovementsAtomically([movement]);
      await database.importMovementsAtomically([movement]);

      expect((await database.getProductById('product'))?.currentStock, 5);
      expect(await database.watchRecentMovements().first, hasLength(1));
    },
  );

  test(
    'locally recorded adjustment sets stock to the exact count including zero',
    () async {
      await database.upsertProduct(
        ProductsTableCompanion.insert(
          id: 'product',
          sku: 'SKU-1',
          name: 'Brake pads',
          costPrice: 10,
          sellingPrice: 15,
          currentStock: const Value(5),
        ),
      );

      await database.insertMovementsAtomically([
        StockMovementsTableCompanion.insert(
          id: 'correction',
          productId: 'product',
          type: 'ADJUSTMENT',
          quantity: 5,
          stockAfter: const Value(0),
        ),
      ]);

      expect((await database.getProductById('product'))?.currentStock, 0);
    },
  );
}
