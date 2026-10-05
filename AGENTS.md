# Project: GearStock

## What this product does
GearStock is a stock management application designed specifically for an Indian bicycle parts shop. It allows the shop owner to efficiently manage inventory, track stock coming in and out, scan barcodes, handle suppliers, and generate reports.

## Stack (do not change without asking)
- Framework: Flutter (latest stable), Dart null-safe, Material 3
- State management: flutter_riverpod (Notifier/AsyncNotifier providers). No setState for business logic, no Provider, Bloc or GetX.
- Navigation: go_router with a StatefulShellRoute for the bottom tabs and route guards
- Local database (source of truth): drift + drift_flutter (SQLite), WAL mode, foreign keys on, migrations, triggers. No sqflite, Hive or shared_preferences for business data.
- Backend (free tier only): Supabase via supabase_flutter for Auth, Postgres sync and Storage bucket "product-images". No Firebase Storage, no paid services.
- Config/secrets: flutter_dotenv (.env in .gitignore)
- Barcode: mobile_scanner. Permissions: permission_handler
- Images: image_picker, flutter_image_compress, cached_network_image, path_provider
- Charts: fl_chart. CSV/share: csv, share_plus. Calls: url_launcher
- Formatting/i18n: intl (en_IN, ₹ grouping, dd-MM-yyyy), flutter_localizations (English)
- Error Tracking: sentry_flutter

## Rules
- Never commit secrets. All secrets go in environment variables, documented in .env.example.
- Run lint and tests before saying a task is done.
- Ask before adding a new dependency.
- Prefer small, reviewable changes.
- Do NOT redesign the UI and do NOT add features outside the specified 10 screens.

## Commands
- Dev: `flutter run`
- Test: `flutter test`
- Lint: `flutter analyze`
- Generate Code: `dart run build_runner build --delete-conflicting-outputs`

## Architecture decisions
See `/docs/decisions/` for the log of decisions and why they were made.
