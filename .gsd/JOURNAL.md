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
