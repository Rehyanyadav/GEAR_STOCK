# Architecture: GearStock

## Component Diagram

```mermaid
graph TD
    UI[Flutter UI Layer\nMaterial 3, go_router]
    State[State Management\nRiverpod AsyncNotifier]
    Domain[Domain Models & Repositories]
    LocalDB[(Local SQLite\nDrift)]
    Backend[(Supabase Backend\nPostgres, Auth, Storage)]
    
    UI <--> State
    State <--> Domain
    Domain <--> LocalDB
    Domain <--> Backend
    LocalDB <..> Backend
```

## Stack Choices

1. **Frontend / Mobile Framework**: Flutter (Dart)
   - *Why*: Allows cross-platform compilation from a single codebase with high performance.
   - *Alternative rejected*: React Native. Flutter is preferred for better performance and built-in Material 3 support.
2. **State Management**: Riverpod (AsyncNotifier)
   - *Why*: Compile-safe, declarative state management that integrates perfectly with async data fetching.
   - *Alternative rejected*: Provider/Bloc. Riverpod is more robust and prevents ProviderNotFound errors at runtime.
3. **Local Database**: Drift (SQLite)
   - *Why*: Type-safe SQLite abstraction for Dart, supporting migrations, WAL mode, and reactive streams.
   - *Alternative rejected*: sqflite/Hive. Drift provides better type safety and relationship mapping.
4. **Backend/BaaS**: Supabase
   - *Why*: Free tier provides Postgres, Auth, and Storage. Perfect for syncing a relational local database to a remote relational database.
   - *Alternative rejected*: Firebase. Project explicitly forbids Firebase Storage and paid services.

## Folder Structure (Feature-First)

```
lib/
├── core/
│   ├── router/          # go_router configurations
│   ├── database/        # Drift database setup and DAOs
│   ├── theme/           # App colors and themes
│   └── exceptions/      # Error handling
├── features/
│   ├── auth/            # Login screen, auth repo, auth notifier
│   ├── dashboard/       # Dashboard screen
│   ├── products/        # Product list, detail, add/edit, scanner
│   ├── stock/           # Stock in, stock out screens
│   ├── suppliers/       # Supplier management
│   └── reports/         # Charting and CSV exports
├── l10n/                # Localization (intl, en_IN)
└── main.dart
```

## Background Jobs
- Currently out of scope for the mobile client. Data sync runs implicitly via Supabase realtime subscriptions or upon app foregrounding.
- Future: Background fetch for offline sync queues.

## Third-Party Services
1. **Supabase**: Auth, Postgres, Storage. Cost: $0 (Free Tier).
2. **Sentry**: Error tracking and crash reporting. Cost: $0 (Free Tier).

## Riskiest Decisions
1. **Offline-first Sync**: Ensuring Drift SQLite correctly resolves conflicts with Supabase Postgres when multiple devices are offline and come back online simultaneously.
2. **Barcode Scanning Performance**: Relying on mobile camera autofocus across various low-end Android devices.
3. **Data Security**: Storing business data locally requires device-level encryption or secure SQLite extensions if device is compromised.
