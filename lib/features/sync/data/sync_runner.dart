import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:drift/isolate.dart' show DriftRemoteException;
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

enum SyncStatusKind { idle, offline, syncing, failed, conflict }

const _stockAdjustmentConflictMessage =
    'Stock changed on another device before this count synced. '
    'Review the current stock and enter the count again.';

bool isStockAdjustmentConflict(Object error) =>
    error is PostgrestException && error.code == '40001';

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
  if (error is PostgrestException) {
    final code = error.code == null ? '' : ' [${error.code}]';
    return 'Supabase error while $stage$code: ${error.message}';
  }
  final sqliteError = _findSqliteException(error);
  if (sqliteError != null) {
    return 'Failed while $stage (SQLite ${sqliteError.extendedResultCode}: '
        '${sqliteError.message}).';
  }
  if (error is Exception) {
    return 'Failed while $stage (${error.runtimeType}: $error).';
  }
  return 'Failed while $stage (${error.runtimeType}).';
}

SqliteException? _findSqliteException(Object error) {
  if (error is SqliteException) return error;
  if (error is DriftRemoteException) {
    return _findSqliteException(error.remoteCause);
  }
  return null;
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

  bool get isCloudUnavailable =>
      isOffline ||
      kind == SyncStatusKind.failed ||
      kind == SyncStatusKind.conflict;
}

final syncStatusProvider = StateProvider<SyncStatus>(
  (ref) => const SyncStatus(),
  name: 'syncStatus',
);

class SyncRunner with WidgetsBindingObserver {
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
  RealtimeChannel? _realtimeChannel;
  String? _realtimeShopId;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<SyncQueueTableData>>? _queueSubscription;
  Timer? _retryTimer;
  Timer? _refreshRetryTimer;
  Timer? _realtimeSyncTimer;
  int _refreshFailures = 0;
  final Set<String> _observedQueueIds = {};
  bool _running = false;
  bool _syncRequested = false;
  bool _disposed = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
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
    if (_disposed || userId == null) return;
    if (_running) {
      _syncRequested = true;
      return;
    }
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
      _ensureRealtimeChannel(shopId);

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
                await _products.deleteProduct(
                  id: change.entityId,
                  shopId: shopId,
                );
                await _images.deleteProductImages(
                  shopId: shopId,
                  productId: change.entityId,
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
                  if (_disposed || _client.auth.currentUser?.id != userId) {
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
                if (_disposed || _client.auth.currentUser?.id != userId) {
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
              if (change.operation == 'delete') {
                await _products.deleteCategory(
                  name: payload['name'] as String,
                  shopId: shopId,
                );
              } else {
                await _products.uploadCategoryPayload(payload, shopId: shopId);
              }
            default:
              throw StateError(
                'Unsupported sync entity "${change.entityType}".',
              );
          }
          if (_disposed || _client.auth.currentUser?.id != userId) return;
          await _queue.acknowledge(change.id);
        } catch (error, stackTrace) {
          if (change.entityType == 'stock_movement' &&
              isStockAdjustmentConflict(error)) {
            await _queue.markConflict(
              change,
              message: _stockAdjustmentConflictMessage,
            );
            try {
              await _products.refreshStockSnapshots(shopId: shopId);
            } catch (refreshError, refreshStackTrace) {
              _reportSyncFailure(
                'refreshing stock after a rejected adjustment',
                refreshError,
                refreshStackTrace,
              );
            }
            final remaining = await _queue.allChanges();
            _onStatus(
              SyncStatus(
                kind: SyncStatusKind.conflict,
                pendingCount: remaining.length,
                message: _stockAdjustmentConflictMessage,
              ),
            );
            continue;
          }
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
          _reportSyncFailure(
            'uploading ${change.entityType}',
            error,
            stackTrace,
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
      stage = 'refreshing stock totals';
      await _products.refreshStockSnapshots(shopId: shopId);
      stage = 'checking the local sync queue';
      final remaining = await _queue.allChanges();
      final hasStockConflict = remaining.any(
        (change) => change.status == 'conflict',
      );
      _refreshFailures = 0;
      _refreshRetryTimer?.cancel();
      _refreshRetryTimer = null;
      _onStatus(
        SyncStatus(
          kind: hasStockConflict
              ? SyncStatusKind.conflict
              : _syncRequested
              ? SyncStatusKind.syncing
              : SyncStatusKind.idle,
          pendingCount: remaining.length,
          message: hasStockConflict ? _stockAdjustmentConflictMessage : null,
        ),
      );
    } catch (error, stackTrace) {
      _onStatus(
        SyncStatus(
          kind: SyncStatusKind.failed,
          message: syncFailureMessage(stage, error),
        ),
      );
      _reportSyncFailure(stage, error, stackTrace);
      _scheduleRefreshRetry();
    } finally {
      _running = false;
      if (_syncRequested && !_disposed) {
        _syncRequested = false;
        unawaited(syncNow());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncNow());
    }
  }

  void _ensureRealtimeChannel(String shopId) {
    if (_realtimeShopId == shopId && _realtimeChannel != null) return;
    final oldChannel = _realtimeChannel;
    if (oldChannel != null) {
      unawaited(_client.removeChannel(oldChannel));
    }

    _realtimeShopId = shopId;
    final channel = _client
        .channel('gearstock-stock-sync-$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => _scheduleRealtimeSync(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stock_movements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => _scheduleRealtimeSync(),
        );
    _realtimeChannel = channel;
    channel.subscribe((status, error) {
      if (_disposed ||
          (status != RealtimeSubscribeStatus.channelError &&
              status != RealtimeSubscribeStatus.timedOut)) {
        return;
      }
      if (identical(_realtimeChannel, channel)) {
        _realtimeChannel = null;
        _realtimeShopId = null;
      }
      if (error != null) {
        _reportSyncFailure(
          'subscribing to realtime stock updates',
          error,
          StackTrace.current,
        );
      }
      _scheduleRefreshRetry();
    });
  }

  void _scheduleRealtimeSync() {
    if (_disposed) return;
    _realtimeSyncTimer?.cancel();
    _realtimeSyncTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(syncNow()),
    );
  }

  void _reportSyncFailure(String stage, Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError(syncFailureMessage(stage, error)),
        stack: stackTrace,
        library: 'GearStock synchronization',
        context: ErrorDescription('while synchronizing shop data'),
      ),
    );
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
    final currentIds = changes.map((change) => change.id).toSet();
    final addedIds = currentIds.difference(_observedQueueIds);
    _observedQueueIds
      ..clear()
      ..addAll(currentIds);
    _retryTimer?.cancel();
    final ready = changes.where((row) {
      if (row.status != 'pending') return false;
      final nextAttemptAt = row.nextAttemptAt;
      return nextAttemptAt == null || !nextAttemptAt.isAfter(DateTime.now());
    }).toList();

    if (changes.isEmpty) {
      if (!_running) unawaited(syncNow());
      return;
    }
    if (ready.isNotEmpty) {
      if (_running) {
        if (ready.any((change) => addedIds.contains(change.id))) {
          _syncRequested = true;
        }
        return;
      }
      unawaited(syncNow());
      return;
    }
    final retryable = changes
        .where((row) => row.status == 'pending' && row.nextAttemptAt != null)
        .toList();
    if (retryable.isEmpty) {
      final hasConflict = changes.any((row) => row.status == 'conflict');
      if (hasConflict) {
        _onStatus(
          SyncStatus(
            kind: SyncStatusKind.conflict,
            pendingCount: changes.length,
            message: _stockAdjustmentConflictMessage,
          ),
        );
      }
      return;
    }
    final nextAttempt = retryable
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
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _refreshRetryTimer?.cancel();
    _realtimeSyncTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _authSubscription?.cancel();
    await _queueSubscription?.cancel();
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    _realtimeShopId = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
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
