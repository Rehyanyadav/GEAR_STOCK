import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/database/app_database.dart';
import 'package:gearstock/features/sync/data/sync_queue_repository.dart';

void main() {
  late AppDatabase database;
  late SyncQueueRepository queue;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueueRepository(database, 'user-a');
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'queue is scoped to its user and remains pending until acknowledged',
    () async {
      final change = createSyncQueueEntry(
        userId: 'user-a',
        entityType: 'product',
        entityId: 'product-1',
        operation: 'upsert',
        payload: const {'name': 'Brake pads'},
      );
      await queue.enqueue(change);
      await database
          .into(database.syncQueueTable)
          .insert(
            createSyncQueueEntry(
              userId: 'user-b',
              entityType: 'product',
              entityId: 'product-2',
              operation: 'upsert',
              payload: const {'name': 'Chain'},
            ),
          );

      final pending = await queue.readyChanges();
      expect(pending, hasLength(1));
      expect(pending.single.userId, 'user-a');

      await queue.acknowledge(pending.single.id);
      expect(await queue.readyChanges(), isEmpty);
      expect(
        await database.select(database.syncQueueTable).get(),
        hasLength(1),
      );
    },
  );

  test(
    'failed changes are deferred with bounded exponential backoff',
    () async {
      await queue.enqueue(
        createSyncQueueEntry(
          userId: 'user-a',
          entityType: 'supplier',
          entityId: 'supplier-1',
          operation: 'upsert',
          payload: const {'name': 'Local supplier'},
        ),
      );

      final change = (await queue.readyChanges()).single;
      await queue.defer(change, StateError('network failure'));

      expect(await queue.readyChanges(), isEmpty);
      final saved = await database.select(database.syncQueueTable).getSingle();
      expect(saved.attempts, 1);
      expect(saved.lastError, 'StateError');
      expect(saved.nextAttemptAt, isNotNull);
    },
  );

  test(
    'stock conflicts stay out of automatic retries until resolved',
    () async {
      await queue.enqueue(
        createSyncQueueEntry(
          userId: 'user-a',
          entityType: 'stock_movement',
          entityId: 'movement-1',
          operation: 'insert',
          payload: const {'product_id': 'product-1', 'type': 'ADJUSTMENT'},
        ),
      );

      final change = (await queue.readyChanges()).single;
      await queue.markConflict(
        change,
        message: 'Stock changed on another device.',
      );

      expect(await queue.readyChanges(), isEmpty);
      expect((await queue.allChanges()).single.status, 'conflict');

      await queue.resolveStockConflictsForProduct('product-1');

      expect(await queue.allChanges(), isEmpty);
    },
  );

  test(
    'queue ties retain insertion order for dependent stock events',
    () async {
      final createdAt = DateTime.utc(2026, 10, 6);
      final product = createSyncQueueEntry(
        userId: 'user-a',
        entityType: 'product',
        entityId: 'product-1',
        operation: 'upsert',
        createdAt: createdAt,
        payload: const {'current_stock': 5},
      );
      final movement = createSyncQueueEntry(
        userId: 'user-a',
        entityType: 'stock_movement',
        entityId: 'movement-1',
        operation: 'insert',
        createdAt: createdAt,
        payload: const {'quantity': 4},
      );
      await queue.enqueue(product);
      await queue.enqueue(movement);

      expect((await queue.readyChanges()).map((change) => change.id), [
        product.id.value,
        movement.id.value,
      ]);
    },
  );

  test(
    'product and outbox write roll back together on queue failure',
    () async {
      final existing = createSyncQueueEntry(
        userId: 'user-a',
        entityType: 'product',
        entityId: 'existing',
        operation: 'upsert',
        payload: const {'name': 'Existing'},
      );
      await queue.enqueue(existing);

      await expectLater(
        database.saveProduct(
          product: ProductsTableCompanion.insert(
            id: 'new-product',
            sku: 'NEW-1',
            name: 'New product',
            costPrice: 1,
            sellingPrice: 2,
          ),
          queuedChange: SyncQueueTableCompanion.insert(
            id: existing.id.value,
            userId: 'user-a',
            entityType: 'product',
            entityId: 'new-product',
            operation: 'upsert',
            payload: '{}',
          ),
        ),
        throwsA(anything),
      );

      expect(await database.getProductById('new-product'), isNull);
      expect(
        await database.select(database.syncQueueTable).get(),
        hasLength(1),
      );
    },
  );
}
