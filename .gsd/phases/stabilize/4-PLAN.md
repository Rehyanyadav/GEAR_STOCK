---
phase: stabilize
plan: 4
wave: 1
title: Restore Reliable Product and Stock Workflows
---

# Plan S.4 — Product, Stock, and Crash Regressions

## Objective
Restore the product details removed from the product form, make selected images durable and compact, and prove stock movements refresh the catalog. Preserve the current 10-screen design and add no dependencies.

## Tasks

1. **Restore shelf/bin location**
   - Reintroduce the location field in add/edit product.
   - Pass the entered value through create/update and retain it when editing.
   - Verify it appears in product detail and stock-entry product summaries.

2. **Make image selection durable and bounded**
   - Support camera and gallery selection with clear error handling.
   - Keep compression and a bounded preview; persist/copy picked files into app-owned storage instead of saving temporary picker paths.
   - Render local files and remote URLs correctly from catalog/detail/edit views.
   - Use the existing Supabase Storage dependency/path when image sync is available; never treat a local filesystem path as a remote URL.

3. **Fix catalog stock refresh**
   - Add a regression test proving stock-in/out updates the local product row and the products provider/list without manual refresh.
   - Fix the Drift notification/query or provider refresh boundary responsible if the test reproduces stale state.

4. **Support shop-defined product categories**
   - Keep category choices backed by the existing categories provider/table.
   - Allow creating and assigning categories, and ensure newly-created choices appear in the catalog filter without restart.

5. **Simplify and stabilize entry flows**
   - Remove only redundant steps/copy in stock-in/out while preserving movement type, quantity validation, references, and multi-item support.
   - Add focused regression coverage for the known bottom-sheet/router/dashboard crash paths in plans 1–3.

## Verification
- Targeted Flutter tests for image/location persistence, category updates, stock-trigger invalidation, and crash-prone widgets.
- `flutter analyze` and `flutter test`.
- Physical iPhone scanner/photo checks after install; report SDK/signing blockers rather than masking them.
