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
    'product deletion archives the product and retains stock history',
    () async {
      await database.upsertCategory(
        CategoriesTableCompanion.insert(id: 'Brakes', name: 'Brakes'),
      );
      await database.upsertProduct(_product(category: 'Brakes'));
      await database.insertMovement(
        StockMovementsTableCompanion.insert(
          id: 'movement',
          productId: 'product',
          type: 'IN',
          quantity: 3,
        ),
      );
      await database
          .into(database.syncQueueTable)
          .insert(
            SyncQueueTableCompanion.insert(
              id: 'movement-queue',
              userId: 'user',
              entityType: 'stock_movement',
              entityId: 'movement',
              operation: 'insert',
              payload: '{"id":"movement"}',
            ),
          );

      await database.deleteProduct(
        'product',
        queuedChange: SyncQueueTableCompanion.insert(
          id: 'product-delete-queue',
          userId: 'user',
          entityType: 'product',
          entityId: 'product',
          operation: 'delete',
          payload: '{"id":"product"}',
        ),
      );

      expect((await database.getProductById('product'))?.isDeleted, isTrue);
      expect(await database.watchAllProducts().first, isEmpty);
      expect(
        (await database.watchRecentMovements().first).map((row) => row.id),
        ['movement'],
      );
      expect(
        (await database.select(database.syncQueueTable).get())
            .map((row) => row.id)
            .toSet(),
        {'movement-queue', 'product-delete-queue'},
      );
    },
  );

  test('category deletion clears product category references', () async {
    await database.upsertCategory(
      CategoriesTableCompanion.insert(id: 'Brakes', name: 'Brakes'),
    );
    await database.upsertProduct(_product(category: 'Brakes'));

    await database.deleteCategory('Brakes');

    final product = await database.getProductById('product');
    expect(product?.categoryId, isNull);
    expect(product?.name, 'Brake pads');
    expect(product?.sku, 'SKU-1');
    expect(product?.costPrice, 10);
    expect(product?.sellingPrice, 15);
    expect(await database.watchAllCategories().first, isEmpty);
  });
}

ProductsTableCompanion _product({required String category}) {
  return ProductsTableCompanion.insert(
    id: 'product',
    sku: 'SKU-1',
    name: 'Brake pads',
    costPrice: 10,
    sellingPrice: 15,
    categoryId: Value(category),
  );
}
