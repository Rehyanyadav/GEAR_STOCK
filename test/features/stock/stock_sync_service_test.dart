import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/database/app_database.dart';
import 'package:gearstock/features/stock/data/stock_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late AppDatabase database;
  late HttpServer server;
  late SupabaseClient client;
  late List<Map<String, dynamic>> remoteMovements;
  final uploadedMovements = <Map<String, dynamic>>[];
  final downloadQueries = <Map<String, String>>[];

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    remoteMovements = [_remoteMovement('remote-movement', 'product')];
    uploadedMovements.clear();
    downloadQueries.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET' &&
          request.uri.path == '/rest/v1/stock_movements') {
        downloadQueries.add(request.uri.queryParameters);
        final cursor = await database.getSyncCursor('stock-movements:v2:shop');
        final sinceFilter = request.uri.queryParameters['synced_at'];
        final available =
            remoteMovements.where((row) {
              if (sinceFilter != null) {
                final since = DateTime.parse(
                  sinceFilter.substring('gte.'.length),
                );
                return !DateTime.parse(
                  row['synced_at'] as String,
                ).isBefore(since);
              }
              if (cursor == null) return true;
              final timeComparison = (row['synced_at'] as String).compareTo(
                cursor.syncedAt,
              );
              return timeComparison > 0 ||
                  (timeComparison == 0 &&
                      (row['id'] as String).compareTo(cursor.lastId) > 0);
            }).toList()..sort((left, right) {
              final timeComparison = (left['synced_at'] as String).compareTo(
                right['synced_at'] as String,
              );
              return timeComparison != 0
                  ? timeComparison
                  : (left['id'] as String).compareTo(right['id'] as String);
            });
        final start =
            int.tryParse(request.uri.queryParameters['offset'] ?? '') ?? 0;
        final limit =
            int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 1000;
        request.response.write(
          jsonEncode(available.skip(start).take(limit).toList()),
        );
      } else if (request.method == 'POST' &&
          request.uri.path == '/rest/v1/stock_movements') {
        final decoded = jsonDecode(
          await utf8.decodeStream(request.cast<List<int>>()),
        );
        if (decoded is List) {
          uploadedMovements.addAll(decoded.cast<Map<String, dynamic>>());
        } else {
          uploadedMovements.add(decoded as Map<String, dynamic>);
        }
        request.response.statusCode = HttpStatus.created;
      } else {
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
    'downloaded movement history does not alter an existing stock total',
    () async {
      await _insertProduct(database, 'product', 5);

      final service = StockSyncService(database, client);
      await service.downloadMovements(shopId: 'shop');
      await service.downloadMovements(shopId: 'shop');

      expect((await database.getProductById('product'))?.currentStock, 5);
      expect(await database.watchRecentMovements().first, hasLength(1));
      expect(
        (await database.getSyncCursor('stock-movements:v2:shop'))?.lastId,
        'remote-movement',
      );
      expect(downloadQueries[2]['or'], contains('synced_at.eq.'));
      expect(downloadQueries.first['order'], contains('synced_at.asc'));
    },
  );

  test(
    'paginates equal ingestion timestamps without skipping movements',
    () async {
      await _insertProduct(database, 'product', 10);
      remoteMovements = List.generate(
        1001,
        (index) => _remoteMovement(
          '00000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
          'product',
        ),
      );

      await StockSyncService(
        database,
        client,
      ).downloadMovements(shopId: 'shop');

      expect(
        await database.select(database.stockMovementsTable).get(),
        hasLength(1001),
      );
      expect(
        (await database.getSyncCursor('stock-movements:v2:shop'))?.lastId,
        remoteMovements.last['id'],
      );
      expect(downloadQueries, hasLength(4));
    },
  );

  test(
    'overlap scan catches a late-committing event behind the cursor',
    () async {
      await _insertProduct(database, 'product', 10);
      remoteMovements = [
        _remoteMovement(
          'later-event',
          'product',
          syncedAt: '2026-10-06T00:05:00.123456Z',
        ),
      ];
      final service = StockSyncService(database, client);
      await service.downloadMovements(shopId: 'shop');
      remoteMovements.add(
        _remoteMovement(
          'late-commit',
          'product',
          syncedAt: '2026-10-06T00:01:00.123456Z',
        ),
      );

      await service.downloadMovements(shopId: 'shop');

      expect(
        await database.select(database.stockMovementsTable).get(),
        hasLength(2),
      );
      expect(
        (await database.getSyncCursor('stock-movements:v2:shop'))?.lastId,
        'later-event',
      );
    },
  );

  test(
    'does not advance the movement cursor when local page import fails',
    () async {
      await expectLater(
        StockSyncService(database, client).downloadMovements(shopId: 'shop'),
        throwsA(anything),
      );

      expect(await database.getSyncCursor('stock-movements:v2:shop'), isNull);

      await _insertProduct(database, 'product', 5);
      await StockSyncService(
        database,
        client,
      ).downloadMovements(shopId: 'shop');

      expect(
        await database.getSyncCursor('stock-movements:v2:shop'),
        isNotNull,
      );
      expect(
        await database.select(database.stockMovementsTable).get(),
        hasLength(1),
      );
    },
  );

  test('uploads exact-count corrections with their resulting stock', () async {
    await StockSyncService(database, client).uploadMovementPayload({
      'id': 'correction',
      'product_id': 'product',
      'type': 'ADJUSTMENT',
      'quantity': -3,
      'stock_after': 2,
      'created_at': '2026-10-06T00:00:00Z',
    }, shopId: 'shop');

    expect(uploadedMovements, [
      {
        'id': 'correction',
        'product_id': 'product',
        'type': 'ADJUSTMENT',
        'quantity': -3,
        'stock_after': 2,
        'created_at': '2026-10-06T00:00:00Z',
        'shop_id': 'shop',
      },
    ]);
  });

  test(
    'rebuilds the movement cursor instead of trusting a legacy future cursor',
    () async {
      await _insertProduct(database, 'product', 10);
      await database
          .into(database.syncCursorsTable)
          .insert(
            SyncCursorsTableCompanion.insert(
              id: 'stock-movements:shop',
              syncedAt: '2099-01-01T00:00:00.000Z',
              lastId: 'poisoned-cursor',
            ),
          );

      await StockSyncService(
        database,
        client,
      ).downloadMovements(shopId: 'shop');

      expect(
        await database.select(database.stockMovementsTable).get(),
        hasLength(1),
      );
      expect(downloadQueries.first, isNot(contains('or')));
      expect(
        (await database.getSyncCursor('stock-movements:v2:shop'))?.lastId,
        'remote-movement',
      );
    },
  );

  test('imported movement rows are append-only and ignore stale duplicate replays',
      () async {
    await _insertProduct(database, 'product', 10);
    final movement = StockMovementsTableCompanion.insert(
      id: 'movement-1',
      productId: 'product',
      type: 'IN',
      quantity: 4,
      note: const Value('first'),
      referenceNumber: const Value('ref-1'),
      unitPrice: const Value(5.0),
      operatorName: const Value('operator'),
      createdAt: Value(DateTime.parse('2026-10-06T00:00:00Z')),
    );
    await database.insertMovement(movement);
    await database.importMovementsAtomically([
      movement.copyWith(
        quantity: const Value(99),
        note: const Value('stale duplicate'),
        referenceNumber: const Value('ref-2'),
      ),
    ]);

    final savedMovement = await database
        .select(database.stockMovementsTable)
        .getSingle();

    expect(savedMovement.quantity, 4);
    expect(savedMovement.note, 'first');
    expect(savedMovement.referenceNumber, 'ref-1');
  });
}

Future<void> _insertProduct(AppDatabase database, String id, int stock) {
  return database.upsertProduct(
    ProductsTableCompanion.insert(
      id: id,
      sku: 'SKU-$id',
      name: 'Brake pads',
      costPrice: 10,
      sellingPrice: 15,
      currentStock: Value(stock),
    ),
  );
}

Map<String, dynamic> _remoteMovement(
  String id,
  String productId, {
  String syncedAt = '2026-10-06T00:00:00.123456Z',
}) => {
  'id': id,
  'product_id': productId,
  'type': 'IN',
  'quantity': 4,
  'stock_after': null,
  'created_at': '2026-10-06T00:00:00Z',
  'synced_at': syncedAt,
};
