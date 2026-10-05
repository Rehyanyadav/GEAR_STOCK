---
phase: stabilize
plan: 3
wave: 2
title: Simplify — Remove Unwanted Complexity
depends_on: [1, 2]
---

# Plan S.3 — Simplify the App for Daily Shop Use

## Objective
Remove jargon, dead UI, and overcomplicated flows that make the app confusing for
a shop owner who just wants to track bicycle spare parts. Keep only what's needed.

## What to Remove / Simplify

| Item | Current State | Action |
|------|--------------|--------|
| "Workshop OS", "Inventory Floor Operations", "Terminal" jargon | All over the app | Replace with plain language: "GearStock", "Add Stock", etc. |
| `_showStockActionSheet` overengineered modal | Has "Log inbound vendor purchase orders & restock parts" etc. | Simplify copy to "Receive Parts" / "Issue Parts" |
| Simulate barcode chips on scanner | Removed ✓ | Already done |
| "Reorder PO" button on low-stock cards | Goes to ProductDetail — confusing | Rename to "View Part" |
| Fake "Live Sync" / "+4.2% this month" hardcoded trend on KPI cards | Misleading | Remove fake trends, show real data or nothing |
| Profile modal hardcoded "Central Workshop - Pune" | Hardcoded location | Remove or make it the shop email |
| `splashRadius` deprecated API on IconButton | Causes warning | Remove it |
| Dashboard greeting always says "Good morning" | Hardcoded | Use time-of-day aware greeting |

## Tasks

<task type="auto">
  <name>Simplify all in-app copy and remove jargon</name>
  <files>
    lib/core/router.dart
    lib/features/dashboard/presentation/dashboard_screen.dart
  </files>
  <action>
    **In router.dart `_AppShell._subtitle`:**
    ```dart
    String get _subtitle => switch (widget.shell.currentIndex) {
      0 => 'Stock Overview',
      1 => 'Parts Catalog',
      2 => 'Reports',
      _ => 'GearStock',
    };
    ```

    **In router.dart `_showStockActionSheet`:**
    - Title: `'Stock Operation'` (was "Inventory Floor Operations")
    - Subtitle: `'What do you want to do?'` (remove "Log inbound vendor purchase orders...")
    - Tile 1: title `'Receive Parts'`, subtitle `'Parts came in from supplier'`
    - Tile 2: title `'Issue / Sell Parts'`, subtitle `'Parts used in repair or sold'`

    **In router.dart `_showProfileModal`:**
    - Remove `'Active Terminal'` / `'Central Workshop - Pune'` ListTile
    - Keep only: name, email, Suppliers link, Logout
    - Remove deprecated `splashRadius` parameter from `IconButton` in dashboard

    **In dashboard_screen.dart:**
    - Replace `'SHOP SNAPSHOT'` label with `'TODAY'S SNAPSHOT'`
    - Fix greeting to be time-of-day aware:
      ```dart
      String _greeting() {
        final hour = DateTime.now().hour;
        if (hour < 12) return 'Good morning';
        if (hour < 17) return 'Good afternoon';
        return 'Good evening';
      }
      ```
      Then use `'${_greeting()}, $currentUser 👋'`
      (DashboardScreen is a ConsumerWidget so add this as a static method or top-level fn)
    - KPI Card trend: Remove fake `'+4.2% this month'` — replace with `'Current value'` for stock value card
    - Low-stock card button: rename `'Reorder PO'` → `'View Part'`
    - `'Cycle Hub & Spares • Ready for inventory'` → use the user's shop name or just `'Bicycle Parts Shop'`
    - Remove `'Real-time log'` badge, replace with `'Last 4 movements'`
    - `'Catalogued Spares'` → `'Total Parts'`
    - `'Low Stock Warning'` → `'Low Stock'`
  </action>
  <verify>flutter analyze lib/core/router.dart lib/features/dashboard/presentation/dashboard_screen.dart 2>&1</verify>
  <done>No analyzer issues. App text uses plain simple language throughout dashboard and nav shell.</done>
</task>

<task type="auto">
  <name>Simplify stock-in / stock-out screens copy and remove bloat</name>
  <files>
    lib/screens/stock_in_screen.dart
    lib/screens/stock_out_screen.dart
    lib/screens/suppliers_screen.dart
  </files>
  <action>
    **stock_in_screen.dart:**
    - AppBar title: `'Receive Parts'` (was "Stock In")
    - Invoice label: `'Invoice / PO Number'` — keep as-is (this is fine)
    - Bottom summary: `'Total Bill'` — keep, but format with ₹ sign using intl

    **stock_out_screen.dart:**
    - AppBar title: `'Issue Parts'` (was "Stock Out")
    - Reference label: `'Job Card / Reference'` — keep
    - Remove `StockMovementType` dropdown complexity — simplify to just two options:
      `'Repair/Service Use'` and `'Counter Sale'`
      Map these to the existing `outboundService` and `outboundSale` types internally.
    - Remove the `_includeGst` toggle for now (uncle doesn't need GST calculation in MVP;
      can be added back later if needed) — ONLY if the GST logic is causing confusion.
      Actually keep the GST toggle since it may be used, but move it below the items list
      so it doesn't clutter the top.

    **suppliers_screen.dart:**
    - The suppliers screen is fine structurally. Just ensure it doesn't crash on empty list
      (add empty state: `'No suppliers yet. Add your first supplier.'`)
  </action>
  <verify>flutter analyze lib/screens/stock_in_screen.dart lib/screens/stock_out_screen.dart lib/screens/suppliers_screen.dart 2>&1</verify>
  <done>No analyzer issues. Screen titles use plain language. Screens don't crash on empty state.</done>
</task>

## Success Criteria
- [ ] No "Terminal", "Workshop OS", "Inventory Floor Operations", "PO" jargon visible to user
- [ ] Dashboard greeting changes based on time of day
- [ ] KPI cards show only real data (no fake "+4.2%" trend)
- [ ] Low-stock card button says "View Part" not "Reorder PO"
- [ ] Stock-in screen says "Receive Parts"
- [ ] Stock-out screen says "Issue Parts"
- [ ] Suppliers screen shows empty state instead of crashing/blank
- [ ] `flutter analyze lib/` reports no issues
