---
phase: stabilize
plan: 2
wave: 1
title: Fix All Runtime Crashes
---

# Plan S.2 — Fix All Runtime Crashes

## Objective
Stop the app from crashing on common operations. Every crash identified below
has a known root cause and a concrete fix. No new features — only stabilization.

## Crashes Found (From Code Audit)

| # | Where | What Crashes | Why |
|---|-------|-------------|-----|
| 1 | `router.dart` L63 | Dashboard "View All" crashes | `findAncestorStateOfType<StatefulNavigationShellState>()!` — force-unwrap on a type that may not be in the tree at that point |
| 2 | `dashboard_screen.dart` L548 | Recent activity divider crashes on empty list | `movements.take(4).last` throws on empty Iterable |
| 3 | `database/app_database.dart` L204 | `watchLowStockProducts` returns everything, not low-stock | `isSmallerOrEqualValue(0)` should be `isSmallerOrEqualValue(t.minStock)` but Drift can't compare two columns directly — needs a raw query |
| 4 | `stock_in_screen.dart` bottom sheet | `Expanded` inside unbounded height `Column` in bottom sheet | `mainAxisSize: MainAxisSize.min` + `Expanded` = layout exception |
| 5 | `stock_out_screen.dart` same issue | Same `Expanded` inside `mainAxisSize.min` Column | Same fix needed |
| 6 | `add_edit_product_screen.dart` | Scanner icon navigates via `Navigator.push` not `context.go/push` | Mixed Navigator + go_router causes state issues and potential crashes on back navigation |

## Tasks

<task type="auto">
  <name>Fix router crash — Dashboard "View All" products navigation</name>
  <files>lib/core/router.dart</files>
  <action>
    In `router.dart` around line 63, replace the fragile `findAncestorStateOfType` call:

    CURRENT (crashes):
    ```dart
    onNavigateToProducts: () =>
        (context as Element).findAncestorStateOfType<
            StatefulNavigationShellState>()!
          ..goBranch(1),
    ```

    REPLACE WITH (safe):
    ```dart
    onNavigateToProducts: () => context.go('/products'),
    ```

    This uses go_router's own navigation which is always safe from anywhere in the tree.
  </action>
  <verify>flutter analyze lib/core/router.dart 2>&1 | grep -c "issue"</verify>
  <done>No analyzer issues in router.dart. "View All" on dashboard navigates to products tab without crash.</done>
</task>

<task type="auto">
  <name>Fix dashboard empty-list crash + low-stock query bug</name>
  <files>
    lib/features/dashboard/presentation/dashboard_screen.dart
    lib/database/app_database.dart
  </files>
  <action>
    **Fix 1 — Empty iterable crash in dashboard_screen.dart around line 548:**
    Replace:
    ```dart
    if (movement != movements.take(4).last)
    ```
    With:
    ```dart
    if (movements.take(4).toList().indexOf(movement) < movements.take(4).length - 1)
    ```
    Or simpler — use an indexed loop approach:
    Replace the `...movements.take(4).map(...)` block with:
    ```dart
    ...() {
      final recent = movements.take(4).toList();
      return [
        for (int i = 0; i < recent.length; i++) ...[
          _buildActivityTile(recent[i], products),
          if (i < recent.length - 1)
            Divider(color: AppColors.surfaceContainerHigh.withAlpha(120), height: 16),
        ],
      ];
    }(),
    ```
    Also add empty-state when no movements:
    If `movements.isEmpty`, show a centered Text('No activity yet') inside the container.

    **Fix 2 — watchLowStockProducts was using `isSmallerOrEqualValue(0)` (wrong):**
    In `app_database.dart`, change `watchLowStockProducts()` to use a raw query
    that correctly compares two columns:
    ```dart
    Stream<List<ProductsTableData>> watchLowStockProducts() {
      return customSelect(
        'SELECT * FROM products WHERE is_deleted = 0 AND current_stock <= min_stock ORDER BY current_stock ASC',
        readsFrom: {productsTable},
      ).watch().map((rows) => rows.map((r) => ProductsTableData(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        sku: r.read<String>('sku'),
        brand: r.readNullable<String>('brand'),
        categoryId: r.readNullable<String>('category_id'),
        costPrice: r.read<double>('cost_price'),
        sellingPrice: r.read<double>('selling_price'),
        currentStock: r.read<int>('current_stock'),
        minStock: r.read<int>('min_stock'),
        shelfLocation: r.readNullable<String>('shelf_location'),
        barcode: r.readNullable<String>('barcode'),
        supplierName: r.readNullable<String>('supplier_name'),
        description: r.readNullable<String>('description'),
        imageUrl: r.readNullable<String>('image_url'),
        isDeleted: r.read<bool>('is_deleted'),
        createdAt: r.read<DateTime>('created_at'),
        updatedAt: r.read<DateTime>('updated_at'),
      )).toList());
    }
    ```
    Note: Check the exact column names and types in `tables/products_table.dart` before writing
    the mapper to make sure field names match exactly.
  </action>
  <verify>flutter analyze lib/features/dashboard/presentation/dashboard_screen.dart lib/database/app_database.dart 2>&1</verify>
  <done>No analyzer issues. Dashboard loads without crash on empty movements list. Low-stock count shows items with stock ≤ minStock.</done>
</task>

<task type="auto">
  <name>Fix stock-in and stock-out bottom-sheet layout crashes</name>
  <files>
    lib/screens/stock_in_screen.dart
    lib/screens/stock_out_screen.dart
  </files>
  <action>
    In both screens, the `_showAddProductDialog` method passes a bottom sheet
    with `mainAxisSize: MainAxisSize.min` AND an `Expanded` child — this crashes
    with "RenderFlex children have non-zero flex but incoming height constraints are unbounded".

    **Fix in stock_in_screen.dart `_showAddProductDialog`:**
    Replace the Column wrapping the ListView with:
    ```dart
    SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,  // fixed height
      child: Column(
        mainAxisSize: MainAxisSize.max,  // NOT min
        children: [
          // header Padding ...
          Expanded(
            child: ListView.builder(...)
          ),
        ],
      ),
    )
    ```

    **Same fix in stock_out_screen.dart `_showAddProductDialog`.**

    Also add `isScrollControlled: true` to the `showModalBottomSheet` call in both
    screens so the sheet can take the full height if needed.
  </action>
  <verify>flutter analyze lib/screens/stock_in_screen.dart lib/screens/stock_out_screen.dart 2>&1</verify>
  <done>No analyzer issues. Stock-in and stock-out product picker sheets open without layout crash.</done>
</task>

## Success Criteria
- [ ] Dashboard "View All" navigates to Products without crash
- [ ] Dashboard shows correct low-stock count (items where stock ≤ minStock, not stock ≤ 0)
- [ ] Dashboard Recent Activity renders on empty list without crash
- [ ] Stock-in product picker sheet opens without RenderFlex crash
- [ ] Stock-out product picker sheet opens without RenderFlex crash
- [ ] `flutter analyze lib/` reports no issues
