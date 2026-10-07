import 'dart:io';

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:gearstock/features/sync/data/sync_runner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('sync status', () {
    test('distinguishes offline and server failure from healthy status', () {
      expect(const SyncStatus(kind: SyncStatusKind.offline).isOffline, isTrue);
      expect(const SyncStatus(kind: SyncStatusKind.failed).isOffline, isFalse);
      expect(
        const SyncStatus(kind: SyncStatusKind.offline).isCloudUnavailable,
        isTrue,
      );
      expect(
        const SyncStatus(kind: SyncStatusKind.failed).isCloudUnavailable,
        isTrue,
      );
      expect(const SyncStatus().isCloudUnavailable, isFalse);
    });
  });

  group('sync refresh retry delay', () {
    test('uses exponential delays for repeated failures', () {
      expect(syncRefreshRetryDelay(1), const Duration(seconds: 1));
      expect(syncRefreshRetryDelay(2), const Duration(seconds: 2));
      expect(syncRefreshRetryDelay(3), const Duration(seconds: 4));
    });

    test('caps the delay at five minutes', () {
      expect(syncRefreshRetryDelay(10), const Duration(minutes: 5));
      expect(syncRefreshRetryDelay(20), const Duration(minutes: 5));
    });

    test('rejects non-positive failure counts', () {
      expect(() => syncRefreshRetryDelay(0), throwsArgumentError);
    });
  });

  group('sync failure message', () {
    test('includes the operating-system reason for socket failures', () {
      final error = SocketException(
        'Connection failed',
        osError: const OSError('DNS lookup failed', 7),
      );

      expect(
        syncFailureMessage('downloading products', error),
        'Network error while downloading products: DNS lookup failed. '
        'The app will retry automatically.',
      );
    });

    test('retains the exception type for non-socket failures', () {
      expect(
        syncFailureMessage('resolving shop membership', StateError('missing')),
        'Failed while resolving shop membership (StateError).',
      );
    });

    test('shows Supabase PostgREST error code and message', () {
      const error = PostgrestException(
        message: 'column stock_movements.synced_at does not exist',
        code: '42703',
      );

      expect(
        syncFailureMessage('downloading stock movements', error),
        'Supabase error while downloading stock movements [42703]: '
        'column stock_movements.synced_at does not exist',
      );
    });

    test('reports the safe SQLite constraint message', () {
      final error = SqliteException(787, 'FOREIGN KEY constraint failed');

      expect(
        syncFailureMessage('downloading products', error),
        'Failed while downloading products '
        '(SQLite 787: FOREIGN KEY constraint failed).',
      );
    });

    test('identifies the server stock-conflict SQL state', () {
      expect(
        isStockAdjustmentConflict(
          const PostgrestException(message: 'stale stock', code: '40001'),
        ),
        isTrue,
      );
      expect(isStockAdjustmentConflict(StateError('network')), isFalse);
    });
  });
}
