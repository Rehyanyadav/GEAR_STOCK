# Testing Strategy: GearStock

## Overview
We employ three levels of automated checks to ensure the application works reliably and regressions are caught early.

## 1. Unit Tests (Business Logic)
- **Target**: Domain models, providers (`Notifiers`), and parsers.
- **Tools**: `flutter test`, `package:test`.
- **Mocks**: External services (Supabase, Sentry) are mocked using `mockito`. Local database (Drift) can use in-memory SQLite instances.

## 2. Widget Tests (UI Components)
- **Target**: Individual screens and complex custom widgets.
- **Tools**: `flutter_test` (WidgetTester).
- **Strategy**: 
  - Render screens in a `ProviderScope`.
  - Override repositories with `_Fake...` implementations to control state.
  - Test the 4 primary UI states: Loading, Error, Empty, Success.
  - Verify accessibility and interaction (e.g., error banners, button disabling).
- **Rule**: DO NOT use `tester.pumpAndSettle()` unconditionally on screens with infinite animations (like spinning loaders). Use `await tester.pump(duration)` to control time manually and avoid timeouts.

## 3. Integration Tests (End-to-End)
- **Target**: Critical user flows executed on a real emulator or physical device.
- **Tools**: `integration_test` package.
- **Critical Flows to Cover**:
  1. Login and Authentication persistence.
  2. Adding a new Product and verifying it appears in the list.
  3. Logging Stock In / Stock Out and verifying quantity updates.
- **Execution**: Run manually before major releases and handled by CI for pull requests.

## Coverage Goals
- Aim for **80%** test coverage on `lib/features/` and `lib/core/`.
- `lib/screens/` (legacy monolithic screens) will be tested thoroughly as they are migrated to `lib/features/`.

## Tooling
- `flutter test` for all unit and widget tests.
- `flutter analyze` for static code quality.
- Sentry integration for real-world crash tracking (manual verification).
