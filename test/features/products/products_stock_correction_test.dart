import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/core/providers.dart';
import 'package:gearstock/core/providers/database_provider.dart';
import 'package:gearstock/database/app_database.dart';
import 'package:gearstock/features/products/data/products_notifier.dart';
import 'package:gearstock/models/product.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authenticatedUserIdProvider.overrideWithValue('user-id'),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test(
    'editing product stock records exact correction and queues it atomically',
    () async {
      await container.read(productsProvider.future);
      final notifier = container.read(productsProvider.notifier);
      await notifier.addProduct(
        name: 'Brake pads',
        sku: 'SKU-1',
        costPrice: 10,
        sellingPrice: 15,
        minStock: 1,
        currentStock: 5,
      );
      final product = (await database.getProductById(
        (await database.select(database.productsTable).getSingle()).id,
      ))!;

      await notifier.updateProduct(
        Product(
          id: product.id,
          name: product.name,
          sku: product.sku,
          category: '',
          brand: '',
          costPrice: product.costPrice,
          sellingPrice: product.sellingPrice,
          currentStock: 9,
          minStock: product.minStock,
          shelfLocation: '',
          barcode: '',
          supplierName: '',
          description: '',
        ),
      );

      final savedProduct = await database.getProductById(product.id);
      final movement = await database
          .select(database.stockMovementsTable)
          .getSingle();
      final queue = await database.select(database.syncQueueTable).get();
      final metadataChange = queue.lastWhere(
        (change) =>
            change.entityType == 'product' && change.entityId == product.id,
      );
      final correctionChange = queue.singleWhere(
        (change) =>
            change.entityType == 'stock_movement' &&
            change.entityId == movement.id,
      );
      final metadataPayload =
          jsonDecode(metadataChange.payload) as Map<String, dynamic>;

      expect(savedProduct?.currentStock, 9);
      expect(movement.type, 'ADJUSTMENT');
      expect(movement.quantity, 4);
      expect(movement.stockAfter, 9);
      expect(metadataPayload.containsKey('current_stock'), isFalse);
      expect(
        jsonDecode(correctionChange.payload),
        containsPair('stock_after', 9),
      );
    },
  );
}
