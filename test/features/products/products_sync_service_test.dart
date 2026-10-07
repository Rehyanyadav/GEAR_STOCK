import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/database/app_database.dart';
import 'package:gearstock/features/products/data/products_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late AppDatabase database;
  late HttpServer server;
  late SupabaseClient client;
  var removeCategoryBeforeProductRead = false;
  final categoryUpserts = <Map<String, dynamic>>[];
  final productPatches = <Map<String, dynamic>>[];
  final requestPaths = <String>[];

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    productPatches.clear();
    requestPaths.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      requestPaths.add('${request.method} ${request.uri.path}');
      if (request.uri.path == '/rest/v1/categories' &&
          request.method == 'POST') {
        final body =
            jsonDecode(await utf8.decodeStream(request.cast<List<int>>()))
                as Map<String, dynamic>;
        categoryUpserts.add(body);
        request.response.write(jsonEncode({'id': 'new-category-id', ...body}));
      } else if (request.uri.path == '/rest/v1/products' &&
          request.method == 'PATCH') {
        productPatches.add(
          jsonDecode(await utf8.decodeStream(request.cast<List<int>>()))
              as Map<String, dynamic>,
        );
        request.response.write(jsonEncode([{'id': 'product-id'}]));
      } else {
        if (request.uri.path == '/rest/v1/products' &&
            removeCategoryBeforeProductRead) {
          removeCategoryBeforeProductRead = false;
          await database.deleteCategory('Brakes');
        }
        switch (request.uri.path) {
          case '/rest/v1/categories':
            request.response.write(
              jsonEncode([
                {'id': 'remote-category-id', 'name': 'Brakes'},
              ]),
            );
          case '/rest/v1/products':
            request.response.write(
              jsonEncode([
                {
                  'id': 'remote-product-id',
                  'name': 'Brake pads',
                  'sku': 'BRAKE-001',
                  'cost_price': 10,
                  'selling_price': 15,
                  'current_stock': 5,
                  'category_id': 'remote-category-id',
                  'created_at': '2026-10-05T00:00:00Z',
                  'updated_at': '2026-10-05T00:00:00Z',
                },
                {
                  'id': 'legacy-product-id',
                  'name': 'Brake cable',
                  'sku': 'BRAKE-002',
                  'cost_price': 5,
                  'selling_price': 8,
                  'current_stock': 0,
                  'category_id': 'brakes',
                  'created_at': '2026-10-05T00:00:00Z',
                  'updated_at': '2026-10-05T00:00:00Z',
                },
              ]),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(
              jsonEncode({'message': 'Unexpected request'}),
            );
        }
      }
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
    await database.close();
  });

  test(
    'stores categories before upserting products that reference them',
    () async {
      final service = ProductsSyncService(database, client);

      await service.downloadProducts(shopId: 'shop-id');

      final product = await database.getProductById('remote-product-id');
      expect(product?.categoryId, 'Brakes');
      final legacyProduct = await database.getProductById('legacy-product-id');
      expect(legacyProduct?.categoryId, 'Brakes');
      expect(
        (await database.watchAllCategories().first).map(
          (category) => category.id,
        ),
        contains('Brakes'),
      );
    },
  );

  test(
    'keeps products syncing if a category disappears during download',
    () async {
      removeCategoryBeforeProductRead = true;
      final service = ProductsSyncService(database, client);

      await service.downloadProducts(shopId: 'shop-id');

      final product = await database.getProductById('remote-product-id');
      expect(product?.name, 'Brake pads');
      expect(product?.categoryId, isNull);
      expect(
        (await database.getProductById('legacy-product-id'))?.name,
        'Brake cable',
      );
    },
  );

  test('uploads categories to the current shop', () async {
    final service = ProductsSyncService(database, client);

    await service.uploadCategoryPayload({
      'name': 'Accessories',
    }, shopId: 'shop-id');

    expect(categoryUpserts, [
      {'name': 'Accessories', 'shop_id': 'shop-id'},
    ]);
  });

  test('archives products without deleting stock movement history', () async {
    await ProductsSyncService(
      database,
      client,
    ).deleteProduct(id: 'product-id', shopId: 'shop-id');

    expect(productPatches, [
      {'is_deleted': true},
    ]);
    expect(requestPaths, ['PATCH /rest/v1/products']);
    expect(requestPaths, isNot(contains('DELETE /rest/v1/stock_movements')));
  });

  test(
    'refreshes cached stock snapshots without applying movement deltas',
    () async {
      await database.upsertProduct(
        ProductsTableCompanion.insert(
          id: 'remote-product-id',
          name: 'Brake pads',
          sku: 'BRAKE-001',
          costPrice: 10,
          sellingPrice: 15,
          currentStock: const Value(9),
        ),
      );

      await ProductsSyncService(
        database,
        client,
      ).refreshStockSnapshots(shopId: 'shop-id');

      expect(
        (await database.getProductById('remote-product-id'))?.currentStock,
        5,
      );
    },
  );
}
