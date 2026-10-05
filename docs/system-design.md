# System Design: GearStock

## Problem Statement
GearStock is a stock management application designed specifically for an Indian bicycle parts shop. It helps the shop owner efficiently manage inventory, track stock coming in and out, scan barcodes, handle suppliers, and generate reports. The primary goal is to digitize inventory tracking that is currently done manually.

## User Roles
1. **Admin / Shop Owner**: Has full access to all features, including adding/editing products, tracking stock, managing suppliers, viewing reports, and managing team members.
2. **Staff / Worker**: Can view products, scan barcodes, and log stock-in/stock-out transactions, but cannot view high-level financial reports or manage the database.

## Core User Flows
1. **Authentication**: Users log in securely to access the system.
2. **Stock Management**: Users scan a barcode (or search manually) to view product details, then log incoming stock (purchases) or outgoing stock (sales/usage).
3. **Product Cataloging**: Adding new bicycle parts, including images, barcodes, category, cost price, and selling price.
4. **Supplier Management**: Adding and editing supplier details for reordering.
5. **Reporting**: Viewing stock levels, low-stock alerts, and transaction history.

## Functional Requirements
- Only 10 specific screens: Login, Dashboard, Products, Add/Edit Product, Product Detail, Stock In, Stock Out, Barcode Scanner, Reports, Suppliers.
- Local-first operation with an offline-capable SQLite database.
- Synchronization with a remote backend (Supabase) for backup and multi-device support.
- Role-based access control.
- Hardware barcode scanning via mobile camera.

## Non-functional Requirements
- **Performance**: Instantaneous UI updates using Riverpod and local SQLite reads.
- **Availability**: App must function completely offline and sync when online.
- **Security**: Data isolation per shop/tenant (if multi-tenant) or per user, secure authentication via Supabase Auth.
- **Localization**: UI should be in English, with Indian formatting (en_IN, ₹ currency, dd-MM-yyyy dates).

## Out of Scope
- Customer management and CRM.
- E-commerce / storefront functionality.
- Payment gateway integration.
- Hardware POS integration (receipt printing, cash drawer).
- Redesigning the current UI.

## Open Questions
- Is multi-tenancy strictly required (multiple independent shops), or is this a single-shop application with multiple staff users? (Assuming single shop, multi-user for now).
