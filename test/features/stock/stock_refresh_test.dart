import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/core/providers/database_provider.dart';
import 'package:gearstock/core/providers.dart';
import 'package:gearstock/database/app_database.dart';
import 'package:gearstock/features/products/data/products_notifier.dart';
import 'package:gearstock/features/stock/data/stock_notifier.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authenticatedUserIdProvider.overrideWithValue(null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('stock movements refresh the product provider immediately', () async {
    final keepProductsAlive = container.listen(productsProvider, (_, _) {});
    addTearDown(keepProductsAlive.close);
    await container.read(productsProvider.future);

    await container.read(productsProvider.notifier).addProduct(
          name: 'Test brake pad',
          sku: 'TEST-BRAKE-1',
          costPrice: 100,
          sellingPrice: 150,
          minStock: 1,
          currentStock: 4,
        );
    await _waitForStock(container, 4);

    final product = container.read(productsProvider).requireValue.single;
    await container.read(stockProvider.notifier).addStockIn(
          productId: product.id,
          quantity: 3,
        );
    expect((await database.getProductById(product.id))?.currentStock, 7);
    await _waitForStock(container, 7);

    await container.read(stockProvider.notifier).addStockOut(
          productId: product.id,
          quantity: 2,
        );
    await _waitForStock(container, 5);
  });
}

Future<void> _waitForStock(ProviderContainer container, int expected) async {
  if (container.read(productsProvider).valueOrNull?.firstOrNull?.currentStock ==
      expected) {
    return;
  }

  final updated = Completer<void>();
  final subscription = container.listen(productsProvider, (_, state) {
    final stock = state.valueOrNull?.firstOrNull?.currentStock;
    if (stock == expected && !updated.isCompleted) updated.complete();
  });
  try {
    await updated.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw TestFailure(
        'Timed out waiting for stock $expected; provider state is '
        '${container.read(productsProvider).valueOrNull?.map((product) => product.currentStock).toList()}.',
      ),
    );
  } finally {
    subscription.close();
  }
}
