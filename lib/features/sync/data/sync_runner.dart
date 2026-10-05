import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../database/app_database.dart';
import '../../products/data/product_image_sync_service.dart';
import '../../products/data/products_sync_service.dart';
import '../../stock/data/stock_sync_service.dart';
import '../../suppliers/data/suppliers_sync_service.dart';
import 'shop_context.dart';
import 'sync_queue_repository.dart';

enum SyncStatusKind { idle, offline, syncing, failed }

Duration syncRefreshRetryDelay(int failureCount) {
  if (failureCount < 1) {
    throw ArgumentError.value(
      failureCount,
      'failureCount',
      'Must be positive.',
    );
  }
  final exponent = (failureCount - 1).clamp(0, 9);
  return Duration(seconds: (1 << exponent).clamp(1, 300));
}

String syncFailureMessage(String stage, Object error) {
  if (error is SocketException) {
    final reason = error.osError?.message ?? error.message;
    final detail = reason.isEmpty ? '' : ': $reason';
    return 'Network error while $stage$detail. The app will retry automatically.';
  }
  return 'Failed while $stage (${error.runtimeType}).';
}

class SyncStatus {
  const SyncStatus({
    this.kind = SyncStatusKind.idle,
    this.pendingCount = 0,
    this.message,
  });

  final SyncStatusKind kind;
  final int pendingCount;
  final String? message;

  bool get isOffline => kind == SyncStatusKind.offline;

  bool get isCloudUnavailable => isOffline || kind == SyncStatusKind.failed;
}

final syncStatusProvider = StateProvider<SyncStatus>(
  (ref) => const SyncStatus(),
  name: 'syncStatus',
);

class SyncRunner {
  SyncRunner({
    required SyncQueueRepository queue,
    required SupabaseClient client,
    required ProductImageSyncService images,
    required ProductsSyncService products,
    required SuppliersSyncService suppliers,
    required StockSyncService stock,
    required void Function(SyncStatus) onStatus,
  }) : _queue = queue,
       _client = client,
       _images = images,
       _products = products,
       _suppliers = suppliers,
       _stock = stock,
       _publishStatus = onStatus;

  final SyncQueueRepository _queue;
  final SupabaseClient _client;
  final ProductImageSyncService _images;
  final ProductsSyncService _products;
  final SuppliersSyncService _suppliers;
  final StockSyncService _stock;
  final void Function(SyncStatus) _publishStatus;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<SyncQueueTableData>>? _queueSubscription;
  Timer? _retryTimer;
  Timer? _refreshRetryTimer;
  int _refreshFailures = 0;
  bool _running = false;
  bool _disposed = false;

  void start() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (!results.contains(ConnectivityResult.none)) {
        unawaited(syncNow());
      }
    });
    _authSubscription = _client.auth.onAuthStateChange.listen((_) {
      unawaited(syncNow());
    });
    _queueSubscription = _queue.watchChanges().listen(_onQueueChanged);
    unawaited(syncNow());
  }

  Future<void> syncNow() async {
    final userId = _client.auth.currentUser?.id;
    if (_disposed || _running || userId == null) return;
    _running = true;
    var stage = 'checking the connection';
    try {
      final connectivity = await _connectivity.checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        stage = 'reading the local sync queue';
        final pending = await _queue.allChanges();
        _onStatus(
          SyncStatus(
            kind: SyncStatusKind.offline,
            pendingCount: pending.length,
            message:
                'No network connection. Changes remain saved on this device.',
          ),
        );
        return;
      }
      stage = 'resolving shop membership';
      final shopId = await resolveCurrentShopId(_client);
      if (_disposed || _client.auth.currentUser?.id != userId) return;

      stage = 'reading the local sync queue';
      final pending = await _queue.readyChanges();
      _onStatus(
        SyncStatus(kind: SyncStatusKind.syncing, pendingCount: pending.length),
      );
      for (final change in pending) {
        if (_disposed || _client.auth.currentUser?.id != userId) return;
        stage = 'uploading ${change.entityType}';
        try {
          final payload = Map<String, dynamic>.from(
            jsonDecode(change.payload) as Map,
          );
          switch (change.entityType) {
            case 'product':
              if (change.operation == 'delete') {
                await _images.deleteProductImages(
                  shopId: shopId,
                  productId: change.entityId,
                );
                await _products.deleteProduct(
                  id: change.entityId,
                  shopId: shopId,
                );
              } else {
                final imageUrl = payload['image_url'] as String?;
                final previousImage = payload['previous_image_url'] as String?;
                if (imageUrl != null &&
                    imageUrl.isNotEmpty &&
                    !imageUrl.startsWith('http://') &&
                    !imageUrl.startsWith('https://') &&
                    !imageUrl.startsWith('supabase://')) {
                  final previousRemoteImage =
                      previousImage?.startsWith('supabase://') == true ||
                          previousImage?.startsWith('http://') == true ||
                          previousImage?.startsWith('https://') == true
                      ? previousImage
                      : null;
                  await _products.uploadProductPayload({
                    ...payload,
                    'image_url': previousRemoteImage,
                  }, shopId: shopId);
                  if (_disposed ||
                      _client.auth.currentUser?.id != userId) {
                    return;
                  }
                  final objectPath = await _images.uploadLocalImage(
                    localPath: imageUrl,
                    productId: change.entityId,
                    shopId: shopId,
                  );
                  payload['image_url'] = 'supabase://$objectPath';
                }
                await _products.uploadProductPayload(payload, shopId: shopId);
                if (_disposed ||
                    _client.auth.currentUser?.id != userId) {
                  return;
                }
                await _images.cleanupReplacedImage(
                  previousImage: previousImage,
                  currentImage: payload['image_url'] as String?,
                );
              }
            case 'supplier':
              await _suppliers.uploadSupplierPayload(payload, shopId: shopId);
            case 'stock_movement':
              await _stock.uploadMovementPayload(payload, shopId: shopId);
            case 'category':
              await _products.deleteCategory(
                name: payload['name'] as String,
                shopId: shopId,
              );
            default:
              throw StateError(
                'Unsupported sync entity "${change.entityType}".',
              );
          }
          if (_disposed || _client.auth.currentUser?.id != userId) return;
          await _queue.acknowledge(change.id);
        } catch (error) {
          await _queue.defer(change, error);
          final remaining = await _queue.watchChanges().first;
          _onStatus(
            SyncStatus(
              kind: SyncStatusKind.failed,
              pendingCount: remaining.length,
              message:
                  '${syncFailureMessage('uploading ${change.entityType}', error)} The change remains queued for retry.',
            ),
          );
          return;
        }
      }

      if (_disposed || _client.auth.currentUser?.id != userId) return;
      stage = 'downloading suppliers';
      await _suppliers.downloadSuppliers(shopId: shopId);
      stage = 'downloading products';
      await _products.downloadProducts(shopId: shopId);
      stage = 'downloading stock movements';
      await _stock.downloadMovements(shopId: shopId);
      stage = 'checking the local sync queue';
      final remaining = await _queue.allChanges();
      _refreshFailures = 0;
      _refreshRetryTimer?.cancel();
      _refreshRetryTimer = null;
      _onStatus(SyncStatus(pendingCount: remaining.length));
    } catch (error, stackTrace) {
      _onStatus(
        SyncStatus(
          kind: SyncStatusKind.failed,
          message: syncFailureMessage(stage, error),
        ),
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'GearStock synchronization',
          context: ErrorDescription('while synchronizing shop data'),
        ),
      );
      _scheduleRefreshRetry();
    } finally {
      _running = false;
    }
  }

  void _scheduleRefreshRetry() {
    if (_disposed) return;
    _refreshRetryTimer?.cancel();
    _refreshFailures++;
    _refreshRetryTimer = Timer(syncRefreshRetryDelay(_refreshFailures), () {
      _refreshRetryTimer = null;
      unawaited(syncNow());
    });
  }

  void _onQueueChanged(List<SyncQueueTableData> changes) {
    if (_disposed) return;
    _retryTimer?.cancel();
    final ready = changes.where((row) {
      final nextAttemptAt = row.nextAttemptAt;
      return nextAttemptAt == null || !nextAttemptAt.isAfter(DateTime.now());
    }).toList();

    if (changes.isEmpty) {
      if (!_running) unawaited(syncNow());
      return;
    }
    if (ready.isNotEmpty) {
      unawaited(syncNow());
      return;
    }
    final nextAttempt = changes
        .map((row) => row.nextAttemptAt!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    _retryTimer = Timer(
      nextAttempt.difference(DateTime.now()),
      () => unawaited(syncNow()),
    );
  }

  void _onStatus(SyncStatus status) {
    if (!_disposed) _publishStatus(status);
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _refreshRetryTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _authSubscription?.cancel();
    await _queueSubscription?.cancel();
  }
}

final syncRunnerProvider = Provider<SyncRunner?>((ref) {
  final queue = ref.watch(syncQueueRepositoryProvider);
  final userId = ref.watch(authenticatedUserIdProvider);
  if (queue == null || userId == null) return null;
  final client = ref.watch(supabaseClientProvider);
  final runner = SyncRunner(
    queue: queue,
    client: client,
    images: ref.watch(productImageSyncServiceProvider),
    products: ref.watch(productsSyncServiceProvider),
    suppliers: ref.watch(suppliersSyncServiceProvider),
    stock: ref.watch(stockSyncServiceProvider),
    onStatus: (status) => ref.read(syncStatusProvider.notifier).state = status,
  );
  runner.start();
  ref.onDispose(() => unawaited(runner.dispose()));
  return runner;
});
