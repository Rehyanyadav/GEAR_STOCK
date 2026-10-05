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

  test('product deletion removes the product and its stock history', () async {
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

    await database.deleteProduct('product');

    expect(await database.getProductById('product'), isNull);
    expect(await database.watchRecentMovements().first, isEmpty);
  });

  test('category deletion clears product category references', () async {
    await database.upsertCategory(
      CategoriesTableCompanion.insert(id: 'Brakes', name: 'Brakes'),
    );
    await database.upsertProduct(_product(category: 'Brakes'));

    await database.deleteCategory('Brakes');

    expect((await database.getProductById('product'))?.categoryId, isNull);
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
