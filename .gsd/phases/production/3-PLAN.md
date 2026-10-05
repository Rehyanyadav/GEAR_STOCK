---
phase: production
plan: 3
wave: 1
depends_on: []
files_modified:
  - supabase/migrations/20240004_shared_shops.sql
  - lib/database/app_database.dart
  - lib/database/app_database.g.dart
  - lib/database/tables/categories_table.dart
  - lib/database/tables/products_table.dart
  - lib/database/tables/suppliers_table.dart
  - lib/database/tables/stock_movements_table.dart
  - lib/core/providers/database_provider.dart
  - test/database/shop_isolation_test.dart
autonomous: true
user_setup:
  - service: supabase
    why: "Apply and validate the shop-membership and RLS migration against the configured project."
    env_vars: []
    dashboard_config: []

must_haves:
  truths:
    - "Authorized users of the same shop can access that shop's records, while users outside it cannot read or modify them."
    - "Local cached records from one shop are never displayed after switching to another shop or signing out."
  artifacts:
    - "supabase/migrations/20240004_shared_shops.sql"
    - "test/database/shop_isolation_test.dart"
  key_links:
    - "Every tenant-scoped table and product-image object is bound to the canonical shop membership."
    - "The local database/cache selection follows the authenticated user's authorized shop."
---

# Plan P.3: Shared-Shop Isolation

<objective>
Implement the confirmed shared-shop tenancy model across Supabase policies and local cache boundaries.

Purpose: Current product/supplier/stock policies are user-scoped, while the desired behavior is shared access within a shop and isolation between shops.
Output: Shop membership, strict tenant-scoped RLS, and tested local account/shop switching.
</objective>

<context>
Load for context:
- `.gsd/SPEC.md`
- `.gsd/ROADMAP.md`
- `supabase/migrations/20240001_products.sql`
- `supabase/migrations/20240002_stock_movements.sql`
- `supabase/migrations/20240003_suppliers.sql`
- `lib/database/app_database.dart`
- `lib/core/providers/database_provider.dart`
</context>

<tasks>
<task type="auto">
  <name>Add shop membership and strict shop-scoped database policies</name>
  <files>supabase/migrations/20240004_shared_shops.sql</files>
  <action>
    Add a forward-only migration for shops and user membership, associate existing business records with the correct shop using an explicit safe backfill, and replace user-only/global-auth policies with policies that authorize membership in that row's shop. Apply the same rule to categories and prepare the same tenant identity for Storage object paths.
    AVOID allowing `USING (true)`/`WITH CHECK (true)` for business records or assuming that authentication alone grants shop access. If legacy rows cannot be assigned unambiguously, make the migration fail with an actionable error rather than assigning them to an arbitrary shop.
  </action>
  <verify>Run Supabase migration validation when the configured CLI/project is available; otherwise inspect the full SQL and add repeatable SQL assertions. Verify same-shop read/write succeeds and non-member cross-shop read/write is denied.</verify>
  <done>Products, categories, suppliers, and stock movements are tenant-scoped by shop membership; migration has a safe legacy-data path and cross-shop negative checks.</done>
</task>
<task type="auto">
  <name>Separate local Drift/cache state by authorized shop and session</name>
  <files>lib/database/app_database.dart, lib/database/tables/categories_table.dart, lib/database/tables/products_table.dart, lib/database/tables/suppliers_table.dart, lib/database/tables/stock_movements_table.dart, lib/core/providers/database_provider.dart, test/database/shop_isolation_test.dart</files>
  <action>
    Bind local reads and writes to the authenticated user's resolved shop and isolate persisted local database/cache state when the shop changes. Close/dispose the previous shop's database before rendering the next account's data; preserve that shop's unsynced work for later rather than deleting or cross-displaying it. Require an authorized shop context before remote operations.
    AVOID SQLCipher, shared-preferences business data, silent fallback to an unscoped database, or destructive cleanup on sign-out.
  </action>
  <verify>`flutter test test/database/shop_isolation_test.dart` plus database migration tests and `flutter analyze` for all modified Dart files.</verify>
  <done>Tests prove shop A data is not observable in shop B after switching, while returning to A retains A's local records.</done>
</task>
</tasks>

<verification>
- [ ] A same-shop member can access shared shop data.
- [ ] A non-member cannot read or write another shop's data remotely or through stale local cache.
</verification>

<success_criteria>
- [ ] Tenant boundaries are enforced in both Supabase and Drift.
- [ ] Migration and local isolation tests pass without deleting pending local work.
</success_criteria>
