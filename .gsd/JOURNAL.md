# Execution journal — 2026-10-04

## Local stabilization and shared-shop sync

### Implemented
- Fixed per-product low-stock thresholds and made stock-in/out batches transactional.
- Added auth rate-limit cooldown handling and reduced-motion behavior.
- Added durable Drift outbox replay, bounded retries, shop-scoped sync requests, paged downloads, account-scoped local database names, and status reporting.
- Added private image upload/download paths and safe replacement cleanup for old local/remote images.
- Explicitly enabled RLS on `storage.objects` in the private product-image migration.

### Verification evidence
- Command: `flutter analyze`
  - Output: `No issues found! (ran in 4.9s)`
- Command: `flutter test`
  - Output: `All tests passed!` (`+30`, 30 tests).
- Applied migrations 1–5 in temporary PostgreSQL database `gearstock_validation`.
  - `storage.objects` reported `rowsecurity = t`.
  - As authenticated owner A, the visible image paths were only those prefixed with owner A's shop UUID.
  - As authenticated owner B, the query returned `own_shop_images = 1` and `foreign_shop_images = 0`.
  - An owner A insert using owner B's shop/product path failed with `new row violates row-level security policy for table "objects"`.
  - The local database used auth/storage stubs and manually granted the standard Storage table privileges; this is not live-Supabase validation.

### Not verified / blockers
- No connection to the configured Supabase project was available; migrations, sync calls, retry/replay, and Storage access must still be checked there.
- The old shared local database has not been imported into per-user databases; preserve it until a safe migration/backup is done.
- Same-account shop reassignment is not gated against stale local rows.
- Current iOS device install is blocked by the embedded `objective_c.framework` signature error; Android SDK/device, production identifiers, and signing configuration remain unavailable/owner-specific.

## Follow-up: live project and iPhone checks

### Supabase read-only inspection
- Checked `.env` without printing values: URL and publishable/anon key entries are present. Auth health returned HTTP 200.
- PostgREST `limit=0` checks returned HTTP 200 for the existing base tables `products`, `suppliers`, `stock_movements`, and `categories`.
- Selecting `shop_id` from those tables returned PostgreSQL `42703` (column missing); requests for `shops` and `shop_memberships` returned PostgREST `PGRST205` (table missing). The configured project has not received the shared-shop migration 20240004. The private Storage migration 20240005 is also pending because it depends on the tenancy helpers/tables.
- No row contents were retrieved and no live schema/data was changed. The existence/ownership of existing rows cannot be established with the unauthenticated read-only checks; back up and preflight in Supabase Dashboard before applying the tenant backfill.
- The selected `http://localhost:54321` in `test/features/products/product_image_sync_service_test.dart` is a dummy Supabase client used only for local file cleanup tests. It is not the configured endpoint.

### iPhone build/install
- `flutter build ios --debug -d 00008110-000205D822A8201E`: succeeded, producing `build/ios/iphoneos/Runner.app`.
- `flutter install -d 00008110-000205D822A8201E`: completed.
- `codesign --verify --deep --strict --verbose=2 build/ios/iphoneos/Runner.app`: `valid on disk`; `satisfies its Designated Requirement`.
- `xcrun devicectl device process launch --device 00008110-000205D822A8201E com.example.gearstock`: launched successfully; installed app identifier/version confirmed.
- Fresh build did not reproduce the previously recorded embedded framework install error. Camera/scanner feed still needs manual device verification.
- `flutter analyze`: no issues. `flutter test`: all 30 passed.

### Supabase SQL Editor permission blocker
- User attempted to run `supabase/migrations/20240005_product_image_storage.sql` and received `ERROR: 42501: must be owner of table objects` on `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY`.
- The migration now checks `pg_class.relrowsecurity` for Supabase-managed `storage.objects` and fails with a GearStock-specific prerequisite message if RLS is off; it no longer attempts to alter ownership-managed Storage schema.
- The error is not evidence that the complete migration succeeded. Do not retry migration 5 yet: project preflight/backup and migration 4 must happen first. Confirm RLS state and rerun the adjusted migration only after that gate.

### User reports migration execution completed
- User reports running `20240005_product_image_storage.sql` successfully and seeing no rows returned (normal for DDL).
- Read-only PostgREST checks after that report return HTTP 200 for `shops`, `shop_memberships`, and `shop_id` on `products`, `suppliers`, `stock_movements`, and `categories`. The shared-shop schema is therefore now present; no remote row values were read.
- Still unverified: whether project data preflight/backup was completed; authenticated shop membership lookup; and local-to-Supabase app writes/retries.
- Do not re-run either migration. Next, sign into the iPhone app to exercise one identifiable test write and observe outbox status.
- User confirmed the SQL Editor query returned `storage_rls_enabled = true` and five `gearstock_product_images_*` policy rows. Storage policy presence is now confirmed; authenticated allow/deny behavior still requires end-to-end validation.
- The user attempted a test sync; product creation is confirmed not attempted earlier, then a later report showed the product persisted locally and the app displayed `Could not refresh shared shop data.`. The sync runner now includes the exception type in the tooltip (without exposing raw PostgREST/server details) for the next retry.
- A read-only SQL Editor check showed membership count `0` for the sign-in account and owner-shop count `1`. This is the likely root cause: `resolveCurrentShopId()` calls `.single()` on that user's memberships. Added an idempotent SQL repair for exactly-one-owner-shop accounts to `docs/shared-shop-access.md`; user must execute it because the agent has no privileged SQL connection.
- The user initially ran the repair with an unreplaced/incorrect email placeholder. They then reported a successful run with the exact sign-in email, but have not yet confirmed the post-insert membership count. Next step is app restart and live test-product sync.
- A later global audit query reported zero owner shops missing their membership. iPhone Safari received Supabase's JSON `No API key found in request` response at the Auth health endpoint, proving mobile network reachability; this is expected when opening the endpoint without an API-key header.
- The user's app continues to show a refresh/connection-closed exception after restart; the current installed binary does not include the new sanitized exception-type tooltip. Do not reinstall until pending local product/outbox data is confirmed safely synced or backed up.

## Product download failure update (2026-10-04)

- Added a regression path for a category disappearing between category and product download: retry the product upsert without its category reference, preserving all other product fields. The sync failure message now identifies safe SQLite constraint details without logging SQL or bind values.
- Verification: `flutter test` passed all 45 tests; `flutter analyze` reported no issues.
- Updated `pubspec.yaml` to `1.0.2+3`; `flutter build ios --debug -d 00008110-000205D822A8201E` built `build/ios/iphoneos/Runner.app`.
- `flutter install -d 00008110-000205D822A8201E` reported `Uninstalling old version...`; `devicectl` subsequently reported Gearstock `1.0.2`, build `3`. Local DB/data preservation is not verified and may have been affected by uninstalling the old app; do not claim otherwise.
- The installed app's signature verifies, its development profile includes the iPhone, and Developer Mode is enabled, but `devicectl` launch was denied because iOS reports the developer app is not explicitly trusted. End-to-end sync is therefore not verified; the user must trust the developer app on the iPhone before launch.
- `flutter build apk --release` could not run because this environment currently reports `No Android SDK found`.

### Android release APK build (2026-10-05)
- Command: `flutter build apk --release`
- Output: `✓ Built build/app/outputs/flutter-apk/app-release.apk (85.8MB)`
- Artifact verification: `build/app/outputs/flutter-apk/app-release.apk`, 85,825,514 bytes.
- SHA-256: `4fadc517ebce881c37476db327880e9c1c84ea3f54e25cb3858314c635de4e7b`.
- APK build succeeded after the earlier Android SDK detection failure; Android runtime/install/sync verification has not been performed.

## Stock consistency and sync hardening (2026-10-06)

### Verification evidence
- `flutter test --no-pub`: `All tests passed!` (`+55` tests).
- Focused stock correction, movement import/paging/cursor, product sync, and outbox tests: 12 passed.
- `flutter analyze --no-pub`: `No issues found! (ran in 4.9s)`.
- `git diff --check` for the implementation's tracked source, test, and documentation paths: passed. An unrestricted check still reports trailing whitespace in the user-provided `issue.txt`; that unrelated file was not modified by this implementation.
- Stock sync regression coverage verifies exact-count corrections, import idempotency without stock trigger side effects, cursor retry safety, paging, and catching a late-committing movement within the five-minute overlap.
- `supabase/migrations/20240006_stock_adjustments.sql` was applied only to an isolated temporary local PostgreSQL validation database earlier in this task. Existing totals remained unchanged by migration; an exact adjustment followed by an IN movement produced the expected total. No production backend/data was accessed or modified for this implementation.

### Rollout / limitations
- Apply migration `20240006_stock_adjustments.sql` to the configured Supabase project before deploying the client build.
- Live Supabase and device-to-device sync were not exercised in this task. Verify an exact-count edit and a subsequent IN/OUT movement using two devices before broad release.
- The five-minute overlap is a bounded recovery window for late database commits; it also avoids repeating a complete movement-history download. Imported movement rows remain idempotent and do not mutate stock totals.
- No automatic five-hour database purge was established. Local-only history can still be lost if app storage is cleared, the app is uninstalled, or the local database is explicitly removed; server sync is required for cross-device recovery.

## Sync cursor integrity audit (2026-10-06)

### Finding and remediation
- Security review found a medium-confidence data-integrity risk: authenticated clients could supply a far-future `synced_at`, advancing other devices' movement cursor beyond ordinary events and causing later ledger rows to be skipped.
- Added `20240007_server_owned_movement_cursor.sql`: normalizes existing future-dated rows, assigns insert timestamps on the server, and rejects timestamp changes on updates.
- Movement downloads now use a versioned local cursor namespace so the next app version performs one idempotent full ledger reimport rather than trusting a potentially poisoned legacy cursor. Imported rows do not reapply stock effects.
- Updated the staged rollout docs. Apply migrations 20240006 and 20240007 in order before deploying this cursor-versioned client. The initial ledger reimport may add load/time on first sync.

### Verification evidence
- `flutter test --no-pub`: `All tests passed!` (`+56` tests).
- Focused `stock_sync_service_test.dart`: 6 passed, including a regression with a preexisting 2099 cursor.
- `flutter analyze --no-pub`: `No issues found! (ran in 5.3s)`.
- Applied migration 20240007 to a temporary local PostgreSQL database with a synthetic future-dated row. Assertions passed: the old future timestamp was normalized, an insert carrying a 2099 timestamp received a server timestamp, and an update attempting to change it retained the server timestamp.
- No production Supabase project or customer data was accessed. Live migration and two-device sync behavior remain rollout checks.
