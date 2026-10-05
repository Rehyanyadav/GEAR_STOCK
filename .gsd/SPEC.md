# SPEC.md — GearStock Stabilization and Release Readiness

> **Status**: `FINALIZED`

## Vision
Make GearStock dependable for daily bicycle-parts inventory work on iOS and Android while preserving the existing Flutter, Riverpod, Drift, and Supabase architecture and the existing 10-screen product scope.

## Goals
1. **Reliable product records** — Product photos display after selection and app restart; shelf/bin location is editable and persists; shop-defined product categories remain usable in the catalog.
2. **Correct stock workflows** — Stock-in and stock-out update product quantities immediately, including when movements are entered in batches; the forms are straightforward for routine shop use.
3. **Working barcode scanning** — Camera permission states, retry/settings recovery, and the live scanner work on the connected iPhone; manual lookup remains available.
4. **Stable offline-first behavior** — Local data remains available offline, changes are not silently lost, and supported changes synchronize when connectivity returns.
5. **Release readiness** — Fix reproducible crashes in the requested flows, add focused regression coverage, verify analysis/tests/builds, and install/run the iOS app on the connected device when signing permits.

## Non-Goals
- Redesigning the application or adding screens outside the existing 10-screen scope.
- Adding dependencies or paid services.
- Publishing to the App Store or Play Store as part of this task.
- Claiming a signed production release without the owner's bundle identifiers, signing assets, and service credentials.

## Constraints
- Follow `AGENTS.md`, `PROJECT_RULES.md`, and the existing Flutter/Riverpod/Drift/Supabase architecture.
- Keep changes small, retain Material 3 conventions, and do not commit secrets.
- Interpret “increase sections in Parts” as the ability to create and use shop-defined product categories, not creating arbitrary new screens.
- No new dependencies without approval.

## Success Criteria
- [ ] Selected product photos render in the catalog and detail/edit surfaces, use bounded dimensions/compression, and survive app restart; remote image references are valid when synced.
- [ ] The scanner opens a live camera feed on the connected iPhone after permission is granted; denied/restricted permission has a useful recovery path and manual lookup works.
- [ ] Stock-in/out movements immediately update the displayed product quantity and remain correct after reopening the app.
- [ ] Shelf/bin location can be edited and remains visible after save, app restart, and stock entry.
- [ ] Users can add and assign custom product categories and filter the catalog by them.
- [ ] Stock-in/out flows remain capable of multi-item entry with reduced unnecessary steps and clear validation.
- [ ] Regression tests cover product persistence, movement-driven stock refresh, image/location persistence, and known crash paths.
- [ ] `flutter analyze` and `flutter test` pass; iOS is installed/launched on the connected iPhone if the available signing configuration permits; Android is built when an SDK is available.
- [ ] Remaining production-only external requirements (service configuration, unique application IDs, signing/provisioning) are listed explicitly and are not represented as completed if unavailable.

## User Stories

### As a shop worker
- I want to scan or search for a part, receive or issue stock, and immediately see the correct stock count.
- I want product photos and shelf/bin locations to help me find the right part.
- I want categories that match how our shop organizes parts.

### As a shop owner
- I want work entered offline to remain safe and synchronize when service returns.
- I want a tested app installed on my iPhone and a clear account of any release setup still required.

## Technical Requirements

| Requirement | Priority | Notes |
|---|---|---|
| Drift remains the local source of truth | Must-have | Keep local reads reactive and preserve existing schema migration conventions. |
| Supabase sync does not silently discard failed writes | Must-have | Retryable sync state and error visibility are required for supported entities. |
| Product image storage is bounded and durable | Must-have | Use existing image compression, app storage, and configured Supabase Storage; no new package. |
| Existing 10-screen scope and no new dependencies | Must-have | Follow repository rules. |
| Device/store signing | External | Use existing local credentials only; never request secrets in chat. |

---

*Finalized from the user's issue list on 2026-10-03.*
