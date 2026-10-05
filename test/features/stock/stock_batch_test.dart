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
    'stock-out batch rolls back earlier movements when later item fails',
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

      await expectLater(
        database.insertMovementsAtomically([
          _outbound(id: 'movement-1', quantity: 3),
          _outbound(id: 'movement-2', quantity: 3),
        ]),
        throwsA(isA<StateError>()),
      );

      expect((await database.getProductById('product'))?.currentStock, 5);
      expect(await database.watchRecentMovements().first, isEmpty);
    },
  );
}

StockMovementsTableCompanion _outbound({
  required String id,
  required int quantity,
}) {
  return StockMovementsTableCompanion.insert(
    id: id,
    productId: 'product',
    type: 'OUT',
    quantity: quantity,
  );
}
