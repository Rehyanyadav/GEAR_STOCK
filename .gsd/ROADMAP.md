# GearStock Stabilization and Production Roadmap

## Phase 1 — Daily Inventory Flows
**Status:** Local code work is complete, including the per-product low-stock threshold and atomic stock batches; focused regression coverage passes. The current iOS debug build succeeds; physical scanner verification remains open.
**Objective:** Fix the reported product, scanner, stock-entry, and stability problems without redesigning the app.

**Plans:** Existing `.gsd/phases/stabilize/1-PLAN.md` through `5-PLAN.md`; do not repeat implemented code tasks. Device-only validation in plan 1 remains open.

**Verification:** Focused tests for database/provider and widget flows, `flutter analyze`, `flutter test`, and physical iPhone camera validation.

## Phase 2 — Branding and Failure Resilience
**Status:** Code implemented. Existing icon/native-splash branding and startup/action feedback were retained; reduced motion, conditional Sentry error capture, and atomic stock batches are covered by code/tests.
**Plans:** `.gsd/phases/production/1-PLAN.md` (GearStock branding and restrained motion), `2-PLAN.md` (bootstrap error capture and atomic stock actions).

## Phase 3 — Shared-Shop Offline and Backend Readiness
**Status:** Local implementation, temporary PostgreSQL policy validation, persistent outbox retries, and refresh retry/status behavior are complete. The configured Supabase schema and Storage policies are reported present, but authenticated live sync, data backup/preflight, legacy database import, and same-account shop reassignment isolation remain unverified.
**Objective:** Make supported local changes durable and safely retryable, synchronize images and records with Supabase, and correct backend migration/security issues found in the audit.

**Plans:** `.gsd/phases/production/3-PLAN.md` (shop membership, RLS, and local account isolation), `4-PLAN.md` (durable offline outbox and retries), `5-PLAN.md` (private product-image storage and cache behavior).

**Verification:** Local tests pass; migrations 1–5 applied to a temporary PostgreSQL instance with shop-isolation and Storage RLS checks. Live PostgREST checks confirm shared-shop schema is present; the user confirmed Storage RLS/policies in SQL Editor. Authenticated app writes and cross-shop behavior remain unverified.

**Execution waves:** Wave 1: plans 1 and 3; Wave 2: plan 2; Wave 3: plan 4; Wave 4: plan 5; Wave 5: plan 6.

## Phase 4 — Device and Release Validation
**Status:** iOS debug builds and prior install/launch verification passed; physical scanner behavior remains unverified. iOS Release/Profile builds now fail closed until an owner-approved bundle ID is configured. Android release builds require owner-provided ID/signing; Android SDK and Gradle wrapper distribution are unavailable in the current environment.
**Objective:** Install and launch on the connected iPhone; validate Android build when an SDK is available; identify signing, identifiers, and environment setup still required for store release.

**Plan:** `.gsd/phases/production/6-PLAN.md`.

**Verification:** Device launch, analyzer, complete test suite, and platform build output. No store-release claim without signed artifacts and owner-provided production configuration.

## Planning Notes
- The prior session plan's confirmed choices are authoritative: existing orange gear logo, brief startup reveal and stock-action confirmation only, shared-shop access, OS-sandboxed local storage, and strict shop-scoped backend RLS. SQLCipher and a separate rate-limit service are out of scope.
- Existing app/database/image scaffolding is retained. Implementers must re-check current source and tests before changing it; these plans list only missing behavior.
- Plan `.gsd/phases/stabilize/1-PLAN.md` contains an obsolete concern that the iOS minimum target may be 12. The current Podfile and project target are 15.5; do not lower or rewrite them merely to satisfy the old plan.
- Current verification: `flutter analyze` passes, `flutter test` passes 34 tests, and the iOS debug build succeeds. Release guards, authenticated backend verification, legacy data preservation/import, and device-only scanner/release checks remain open; see `.gsd/STATE.md` and `.gsd/JOURNAL.md` for evidence.
