---
phase: stabilize
plan: 5
wave: 1
depends_on: []
files_modified:
  - lib/database/app_database.dart
  - test/database/low_stock_products_test.dart
autonomous: true
user_setup: []

must_haves:
  truths:
    - "A product is low-stock when current stock is less than or equal to its own minimum stock."
    - "Products above their minimum stock are excluded from the low-stock stream."
  artifacts:
    - "test/database/low_stock_products_test.dart"
  key_links:
    - "watchLowStockProducts compares the two database columns and the regression test exercises that query."
---

# Plan S.5: Correct the Low-Stock Query

<objective>
Correct the remaining low-stock predicate and protect it with a focused Drift regression test.

Purpose: The current query uses `current_stock <= 0`, which misses products below a positive configured minimum.
Output: Correct query behavior and a passing targeted test.
</objective>

<context>
Load for context:
- `.gsd/SPEC.md`
- `lib/database/app_database.dart`
- `lib/database/tables/products_table.dart`
- `test/features/stock/stock_refresh_test.dart`
</context>

<tasks>
<task type="auto">
  <name>Test low-stock threshold behavior and fix the query</name>
  <files>lib/database/app_database.dart, test/database/low_stock_products_test.dart</files>
  <action>
    Add a focused in-memory Drift test with products below, at, and above their respective minimums, including a zero minimum. Change `watchLowStockProducts()` to include non-deleted products where `current_stock <= min_stock`, using the repository's supported Drift/raw-query pattern.
    AVOID comparing against a hard-coded zero or introducing generated-code edits unless the selected query requires them; the expected threshold is per product.
  </action>
  <verify>`flutter test test/database/low_stock_products_test.dart` and `flutter analyze lib/database/app_database.dart test/database/low_stock_products_test.dart`</verify>
  <done>The test includes precisely the products at/below their own thresholds; both targeted commands pass.</done>
</task>
</tasks>

<verification>
- [ ] Positive minimum-stock thresholds are honored.
- [ ] Deleted products and products above their threshold are excluded.
</verification>

<success_criteria>
- [ ] The focused regression test passes.
- [ ] No generated database source is stale if the implementation required code generation.
</success_criteria>
