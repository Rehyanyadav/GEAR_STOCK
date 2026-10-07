# GearStock

GearStock is a Flutter stock-management app for bicycle-parts shops in India. It helps shop owners manage products and suppliers, record incoming and outgoing stock, scan barcodes, and review reports. Inventory is stored locally and synchronizes with Supabase.

## Features

- Sign in with Supabase authentication.
- Manage products, categories, suppliers, and product images.
- Record stock-in and stock-out movements.
- Scan product barcodes.
- View dashboard and inventory reports.
- Store data locally with Drift and synchronize with Supabase.
- English (India) and Hindi localization, with light and dark themes.

## Requirements

- Flutter SDK compatible with the version constraint in `pubspec.yaml` (Dart `^3.11.5`).
- A configured Flutter target device or emulator.
- A Supabase project for authentication and cloud synchronization.

## Getting started

1. Clone the repository and enter the project directory:

   ```bash
   git clone https://github.com/Rehyanyadav/GEAR_STOCK.git
   cd GEAR_STOCK
   ```

2. Create a local environment file from the example:

   ```bash
   cp .env.example .env
   ```

   Set `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in `.env` to the values for your Supabase project. `SUPABASE_ANON_KEY` is supported as a legacy fallback if the publishable key is not set. `SENTRY_DSN` is optional.

   The app uses client-side Supabase credentials. Never put a Supabase service-role key or other privileged secret in `.env` or in the app.

3. In Supabase, apply the SQL migrations in `supabase/migrations/` in filename order. Configure the project's authentication and database policies before using it with real shop data.

4. Fetch packages and run the app:

   ```bash
   flutter pub get
   flutter run
   ```

## Development

Run static analysis and tests with:

```bash
flutter analyze
flutter test
```

Regenerate Drift and Riverpod generated code after changing annotated database or provider sources:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Configuration and secrets

- `.env.example` documents the required and optional environment variables.
- Keep the real `.env` file local; it is excluded by `.gitignore`.
- Do not commit signing keys, service-role keys, access tokens, or other credentials.
- If a credential is accidentally committed or exposed, revoke or rotate it. Removing it in a later commit does not remove it from Git history.

## Project layout

- `lib/features/` — authentication, dashboard, products, stock, suppliers, and synchronization.
- `lib/database/` — Drift database and table definitions.
- `lib/screens/` — inventory, barcode, stock, supplier, and report screens.
- `lib/core/` — shared providers and app routing.
- `lib/l10n/` — localization resources and generated localization code.
- `supabase/migrations/` — Supabase database and storage migrations.
- `test/` — unit and widget tests.
