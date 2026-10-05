# GearStock Production State — 2026-10-04

## Objective and status
Implement the remaining local stabilization, branding/error-resilience, shared-shop, offline-sync, and private-image work without repeating already-present features. Core code and local verification are substantially complete. **Production readiness is not complete**: live Supabase, account reassignment/legacy-cache handling, and signed physical-device release checks remain open.

## Implemented
- Existing gear branding, native launch assets, short startup reveal, and stock success feedback were retained; reduced-motion settings now skip or stop nonessential animation.
- Low-stock queries compare each product's current stock with its own minimum. Stock-in/out batches use Drift transactions and roll back as a unit.
- Auth rate-limit responses surface a bounded cooldown instead of an unhandled error.
- Bootstrap and uncaught Flutter/platform errors are connected to Sentry when configured.
- Drift has a versioned durable outbox; supported local product, supplier, and movement mutations enqueue atomically. Sync retries with bounded backoff, surfaces status, uses stable movement IDs, and pulls records in pages of 1,000.
- Sync distinguishes no network interface from a failed cloud request, retries refresh failures with capped exponential backoff, and downloads products once after supplier/movement pulls.
- Android release builds now require owner-provided application ID and local release signing configuration; iOS Release/Profile builds reject the template bundle ID. Local signing config files are ignored by Git.
- Sync operations capture the authenticated shop context and pass that shop ID to each request; server RLS remains the security boundary.
- Local database filenames are account-scoped. Private product images upload under shop/product paths, render through authenticated memory-only requests, and replaced local/remote images are cleaned only after the replacement write succeeds.
- Shared-shop and private Storage migrations enforce shop membership. Migration `20240005_product_image_storage.sql` verifies that Supabase-managed `storage.objects` already has RLS enabled instead of attempting to alter the managed table.
- The migration workflow and trusted administrator-only teammate provisioning are documented in `docs/shared-shop-access.md`.

## Verification evidence
- `flutter analyze`: passed with no issues after sync-status and release-configuration changes.
- `flutter test`: passed, 34 tests; includes sync retry/status, low-stock thresholds, stock batch rollback, queue/account isolation, image cleanup, login, and widget regressions.
- Migrations 1–5 applied to a temporary local PostgreSQL validation database. Seeded shop A/B queries returned only the caller's shop rows. Storage RLS was enabled; shop A saw only its image paths, shop B saw only its own, and a shop A cross-shop image insert was rejected by RLS.
- The local PostgreSQL run uses Supabase auth/storage stubs. It is not a deployment or substitute for testing against the configured Supabase project.
- Configured Supabase Auth health endpoint returned HTTP 200. Initial read-only PostgREST checks confirmed base business tables but no shared-shop schema. After the user's SQL Editor action, a second read-only check returned HTTP 200 for `shops`, `shop_memberships`, and `shop_id` on products, suppliers, stock movements, and categories, confirming the tenancy schema is now present. The user reports migration 20240005 also ran successfully with no result rows; DDL success returns no result rows normally. The user confirmed a read-only SQL Editor check showed `storage.objects` RLS enabled and all five `gearstock_product_images_*` policies present. Live authenticated app writes remain unverified.
- Fresh `flutter build ios --debug -d 00008110-000205D822A8201E` succeeded. `codesign --verify --deep --strict --verbose=2 build/ios/iphoneos/Runner.app` reported a valid app and designated requirement. `flutter install -d 00008110-000205D822A8201E` completed; `devicectl` confirmed `com.example.gearstock` was installed and launched. This current build did not reproduce the earlier `objective_c.framework` install rejection. Physical scanner/camera behavior has not yet been manually tested.
- `flutter build ios --debug --no-codesign` passed after the release-ID gate. A no-codesign iOS Release build now fails intentionally with the actionable message to configure `ios/Flutter/Local.xcconfig`.
- Android validation is unavailable in the current environment: Flutter reports no Android SDK, and the Gradle wrapper distribution is not present. The release gate is implemented but could not be built here.

## Remaining work and blockers
- The shared-shop schema and Storage policies are now reported/present according to read-only API and SQL Editor checks. Confirm whether the project data preflight and backup were completed. Then verify authenticated membership resolution, app sync, two-shop access, offline replay, retry/idempotency, and image access.
- The first attempt to run migration 20240005 in Supabase SQL Editor failed at `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY` with `must be owner of table objects`. The migration was adjusted to check the platform-managed RLS prerequisite rather than altering the managed table. The user later reported success and confirmed RLS plus all five policies.
- The account-specific local DB has not yet imported the old shared `gearstock` database. Do not delete the old file until its data is safely migrated or backed up.
- Local DB identity is per user, not per shop. Reassigning the same account to a different shop could expose stale local rows before a successful shop refresh; add a validated shop-context gate/reset before treating reassignment as safe.
- Current debug build installed and launched on the connected iPhone; verify camera/scanner permissions and feed manually. The prior nested framework signature problem was not reproduced on this build, but its root cause was not independently identified.
- Android SDK/device validation, permanent owner-approved reverse-DNS IDs, and non-debug release signing remain outstanding. Do not invent identifiers or commit signing secrets.
- Runner/service transformations have not yet been exercised using an authenticated app session against the configured Supabase project; local SQL policy checks and anonymous PostgREST schema requests do not prove remote service compatibility.
- The user reported a connection-closed failure during shop refresh. Current code reports the failing stage and exception type, distinguishes request failure from offline status, retries refreshes, and retains outbox entries. Rebuild/reinstall before testing the updated behavior; authenticated sync success remains unverified.
- A read-only SQL Editor check found zero `shop_memberships` rows for the signed-in account but exactly one shop owned by that account. This explains why `resolveCurrentShopId()` fails during refresh. The user reports the corrected owner-membership INSERT succeeded; the post-insert count has not yet been confirmed. Restart the app to trigger sync, then verify the count and test product in Supabase.
- A read-only global owner audit now reports zero owner shops missing a membership. On iPhone Safari, the Supabase Auth health URL returned `No API key found in request`, which confirms the phone reached Supabase; Safari omitted the API key as expected. Read-only requests from the development environment returned HTTP 200 for configured Auth health and core PostgREST schema endpoints after transient connection interruptions.
- Release setup instructions are in `docs/release.md`. Owner-approved IDs, Android keystore, Apple signing/provisioning, Android SDK/device, scanner verification, signed-in Supabase sync, and safe legacy database import/shop-context isolation remain outstanding.

## Plan reconciliation
- Stabilization plans 1–4 describe work already present; low-stock behavior from plan 5 is implemented and covered.
- Production plans 1–5 are substantially implemented in code; live backend and physical-device/release evidence remain open. Plan 6 is blocked on owner-specific identifiers/signing and host/device tooling.
- The iOS deployment target is already 15.5; do not change it to satisfy stale planning notes.
