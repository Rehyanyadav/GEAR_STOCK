---
phase: production
plan: 2
wave: 2
depends_on: [1]
files_modified:
  - lib/main.dart
  - test/main_error_handling_test.dart
  - lib/database/app_database.dart
  - lib/features/stock/data/stock_notifier.dart
  - lib/screens/stock_in_screen.dart
  - lib/screens/stock_out_screen.dart
  - test/features/stock/stock_batch_test.dart
autonomous: true
user_setup: []

must_haves:
  truths:
    - "Uncaught Flutter and platform errors are reported through Sentry when configured, without exposing credentials or failing silently."
    - "A multi-item stock operation is all-or-nothing locally and reports persistence failures to the user."
  artifacts:
    - "test/main_error_handling_test.dart"
    - "test/features/stock/stock_batch_test.dart"
  key_links:
    - "Sentry is wired to framework and platform error hooks during bootstrap."
    - "Each batch writes all movements and applies stock triggers inside one Drift transaction."
---

# Plan P.2: Crash and Stock-Data Resilience

<objective>
Make startup/error capture explicit and prevent partially committed multi-item stock operations.

Purpose: Existing Sentry initialization is conditional but does not yet establish complete error boundaries; multi-item entry must not leave half a batch committed.
Output: Tested global error reporting and atomic local stock batches with visible failures.
</objective>

<context>
Load for context:
- `.gsd/SPEC.md`
- `.gsd/ROADMAP.md`
- `lib/main.dart`
- `lib/database/app_database.dart`
- `lib/features/stock/data/stock_notifier.dart`
- `lib/screens/stock_in_screen.dart`
- `lib/screens/stock_out_screen.dart`
</context>

<tasks>
<task type="auto">
  <name>Connect uncaught framework and platform errors to configured Sentry</name>
  <files>lib/main.dart, test/main_error_handling_test.dart</files>
  <action>
    Keep local startup functional when the optional Sentry DSN is absent. When configured, initialize Sentry and route Flutter framework and platform dispatcher uncaught errors through its supported Flutter SDK hooks. Keep bootstrap failures explicit and ensure reported events do not include environment secrets or raw auth tokens.
    AVOID catching and discarding arbitrary exceptions or treating invalid/missing Supabase configuration as a successful startup.
  </action>
  <verify>`flutter analyze lib/main.dart test/main_error_handling_test.dart` and `flutter test test/main_error_handling_test.dart`; inject a framework error and assert the configured reporter receives it.</verify>
  <done>Framework and platform uncaught-error paths are covered; missing optional Sentry configuration does not break app startup, and failures remain observable.</done>
</task>
<task type="auto">
  <name>Make multi-item stock entry atomic and surface failures</name>
  <files>lib/database/app_database.dart, lib/features/stock/data/stock_notifier.dart, lib/screens/stock_in_screen.dart, lib/screens/stock_out_screen.dart, test/features/stock/stock_batch_test.dart</files>
  <action>
    Add a Drift transaction boundary for each submitted multi-item stock action so every movement and trigger-driven quantity update commits together or rolls back together. Preserve existing movement types, validation, and references. Let persistence errors reach the established screen error presentation and do not show success feedback until commit.
    AVOID silently swallowing insert failures or changing the existing stock semantics.
  </action>
  <verify>`flutter test test/features/stock/stock_batch_test.dart test/features/stock/stock_refresh_test.dart` and analyze all listed Dart files.</verify>
  <done>Tests prove full commit and rollback behavior for a multi-item batch; failed operations show an error and do not show success feedback.</done>
</task>
</tasks>

<verification>
- [ ] Framework and platform error hooks are tested.
- [ ] A forced mid-batch persistence error leaves no partial stock change.
</verification>

<success_criteria>
- [ ] Error paths are visible and do not return success-shaped fallbacks.
- [ ] Targeted tests and analyzer pass.
</success_criteria>
