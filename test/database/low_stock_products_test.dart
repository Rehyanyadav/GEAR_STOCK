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

  test('low-stock stream compares stock with each product minimum', () async {
    await database.upsertProduct(_product(
      id: 'below',
      sku: 'BELOW',
      currentStock: 2,
      minStock: 5,
    ));
    await database.upsertProduct(_product(
      id: 'at',
      sku: 'AT',
      currentStock: 3,
      minStock: 3,
    ));
    await database.upsertProduct(_product(
      id: 'above',
      sku: 'ABOVE',
      currentStock: 4,
      minStock: 3,
    ));
    await database.upsertProduct(_product(
      id: 'zero-minimum',
      sku: 'ZERO',
      currentStock: 0,
      minStock: 0,
    ));
    await database.upsertProduct(
      _product(
        id: 'deleted',
        sku: 'DELETED',
        currentStock: 0,
        minStock: 10,
      ).copyWith(isDeleted: const Value(true)),
    );

    final ids = (await database.watchLowStockProducts().first)
        .map((product) => product.id)
        .toSet();

    expect(ids, {'below', 'at', 'zero-minimum'});
  });
}

ProductsTableCompanion _product({
  required String id,
  required String sku,
  required int currentStock,
  required int minStock,
}) {
  return ProductsTableCompanion.insert(
    id: id,
    sku: sku,
    name: id,
    costPrice: 1,
    sellingPrice: 2,
    currentStock: Value(currentStock),
    minStock: Value(minStock),
  );
}
