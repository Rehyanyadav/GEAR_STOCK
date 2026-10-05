---
phase: production
plan: 4
wave: 3
depends_on: [2, 3]
files_modified:
  - lib/database/app_database.dart
  - lib/database/app_database.g.dart
  - lib/database/tables/sync_queue_table.dart
  - lib/features/products/data/products_notifier.dart
  - lib/features/products/data/products_sync_service.dart
  - lib/features/suppliers/data/suppliers_notifier.dart
  - lib/features/suppliers/data/suppliers_sync_service.dart
  - lib/features/stock/data/stock_notifier.dart
  - lib/features/stock/data/stock_sync_service.dart
  - lib/features/sync/data/sync_queue_repository.dart
  - lib/features/sync/data/sync_runner.dart
  - lib/features/sync/presentation/sync_status_provider.dart
  - lib/widgets/app_header.dart
  - test/features/sync/sync_queue_test.dart
  - test/features/sync/sync_retry_test.dart
autonomous: true
user_setup: []

must_haves:
  truths:
    - "A locally committed product, supplier, or movement is durably queued until the server acknowledges it."
    - "Offline/retryable failures survive app restart and retry with bounded backoff; permanent failures are visible and are not silently discarded."
    - "Duplicate retries do not create duplicate stock movements or double-apply stock."
  artifacts:
    - "lib/database/tables/sync_queue_table.dart"
    - "lib/features/sync/data/sync_runner.dart"
    - "test/features/sync/sync_queue_test.dart"
  key_links:
    - "Local mutation and outbox enqueue commit in the same Drift transaction."
    - "Connectivity/auth restoration wakes the runner, which removes only acknowledged queue entries."
---

# Plan P.4: Durable Offline Synchronization

<objective>
Wire the existing Supabase sync services into an offline-first, persistent outbox with observable retry state.

Purpose: Sync methods currently exist but have no callers, and their PostgREST catches only print in debug assertions.
Output: Transactional outbox, per-entity upload/download integration, bounded retry, and user-visible sync state.
</objective>

<context>
Load for context:
- `.gsd/SPEC.md`
- `.gsd/ROADMAP.md`
- `lib/features/products/data/products_sync_service.dart`
- `lib/features/stock/data/stock_sync_service.dart`
- `lib/features/suppliers/data/suppliers_sync_service.dart`
- `lib/core/providers.dart`
- `connectivity_plus` already exists in `pubspec.yaml`.
</context>

<tasks>
<task type="auto">
  <name>Create a versioned persistent outbox with atomic enqueue</name>
  <files>lib/database/app_database.dart, lib/database/tables/sync_queue_table.dart, lib/features/sync/data/sync_queue_repository.dart, test/features/sync/sync_queue_test.dart</files>
  <action>
    Add a Drift outbox containing tenant identity, entity type/id, operation/payload, attempt count, next retry time, and last error/status. Add a migration without disturbing existing business data. Expose enqueue/acknowledge/retry operations, and make each supported local mutation plus its queue record atomic.
    AVOID memory-only retry state, deleting queue rows before server acknowledgement, or including secrets in payload/error text.
  </action>
  <verify>`flutter test test/features/sync/sync_queue_test.dart` proves restart persistence, atomic enqueue/rollback, and acknowledgement removal; run Drift code generation and analyze affected files.</verify>
  <done>Queued mutations survive database close/reopen and a failed local transaction leaves neither a partial business change nor an orphan queue item.</done>
</task>
<task type="auto">
  <name>Wire product and supplier mutations to shop-scoped sync</name>
  <files>lib/features/products/data/products_notifier.dart, lib/features/products/data/products_sync_service.dart, lib/features/suppliers/data/suppliers_notifier.dart, lib/features/suppliers/data/suppliers_sync_service.dart</files>
  <action>
    Enqueue create/update/soft-delete operations after local persistence, implement authenticated shop-scoped downloads/upserts, and retain pending queue entries on network or authorization errors. Return errors/status to the sync runner rather than swallowing exceptions. Use the existing service/provider patterns.
    AVOID skipping unauthenticated pending work, unscoped downloads, or treating a debug-only print as error reporting.
  </action>
  <verify>Focused tests for product/supplier local-first writes, downloads, and failed upload retention; analyze all modified files.</verify>
  <done>Product and supplier changes remain immediately available offline and are not acknowledged until authorized server writes succeed.</done>
</task>
<task type="auto">
  <name>Retry stock movement uploads and expose sync status</name>
  <files>lib/features/stock/data/stock_notifier.dart, lib/features/stock/data/stock_sync_service.dart, lib/features/sync/data/sync_runner.dart, lib/features/sync/presentation/sync_status_provider.dart, lib/widgets/app_header.dart, test/features/sync/sync_retry_test.dart</files>
  <action>
    Queue each committed movement, replay by stable movement ID, and keep retries idempotent so the remote insert/trigger cannot apply stock twice. Retry on connectivity restoration and authenticated session recovery with bounded exponential backoff; expose pending/error state through the existing UI surface. Configure/use existing Supabase Auth limits, database constraints, idempotency, and retry controls; debounce only for usability.
    AVOID treating client throttling as a security boundary or silently returning a success-shaped result after remote failure.
  </action>
  <verify>`flutter test test/features/sync/sync_retry_test.dart test/features/stock/stock_refresh_test.dart`; simulate offline restart, reconnection, auth unavailable, and duplicate replay; run targeted analyzer.</verify>
  <done>Offline movements survive restart, replay once after reconnection, and outstanding/permanent errors are visible; duplicate replay does not double-apply stock.</done>
</task>
</tasks>

<verification>
- [ ] Product, supplier, and stock mutations are local-first and durably queued.
- [ ] Transient failures retry; permanent/authorization errors stay visible and queued for resolution.
- [ ] Shop context is enforced for every network operation.
</verification>

<success_criteria>
- [ ] Targeted queue/retry tests and `flutter analyze` pass.
- [ ] No change is lost on offline operation, process restart, or temporary backend failure.
</success_criteria>
