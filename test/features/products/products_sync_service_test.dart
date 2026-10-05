import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/database/app_database.dart';
import 'package:gearstock/features/products/data/products_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late AppDatabase database;
  late HttpServer server;
  late SupabaseClient client;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
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
                'category_id': 'remote-category-id',
                'created_at': '2026-10-05T00:00:00Z',
                'updated_at': '2026-10-05T00:00:00Z',
              },
            ]),
          );
        default:
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'message': 'Unexpected request'}));
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
      expect(
        (await database.watchAllCategories().first).map(
          (category) => category.id,
        ),
        contains('Brakes'),
      );
    },
  );
}
