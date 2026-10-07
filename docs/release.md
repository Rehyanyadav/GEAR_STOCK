# Release build setup

Debug builds continue to use the development application ID. Android release
builds intentionally fail until an owner-approved application ID and release
keystore are configured locally.

Create `android/key.properties` (this file is ignored by Git) with the values
below. Keep the keystore outside source control and back it up securely; losing
the signing key can prevent future updates to the published app.

```properties
applicationId=com.yourcompany.gearstock
storeFile=/absolute/path/to/gearstock-release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

The application ID must be the permanent ID selected for the Android Play
listing. Never copy keystore passwords into source files, chat, or CI logs.
Build with `flutter build appbundle --release`; the build should fail with an
actionable message if the local ID or signing configuration is missing.

iOS distribution still requires an owner-approved permanent bundle identifier
and Apple Developer signing/provisioning setup in Xcode. Set
`GEARSTOCK_BUNDLE_ID` in the ignored `ios/Flutter/Local.xcconfig`; Release and
Profile builds reject the template `com.example.*` identifier. Do not treat a
debug device build as a signed App Store release. Before store submission,
verify the signed release artifact, install/launch it on a physical device,
exercise camera permissions and barcode scanning, and complete a signed-in
Supabase sync test.

Before that sync test, apply the migrations in `supabase/migrations` to the
Supabase project configured in `.env`, in order. In particular,
`20240004_shared_shops.sql` creates shop membership and backfills shop IDs;
back up and preflight existing shop data before applying it.
`20240005_product_image_storage.sql` configures private product-image access.
Before releasing a client that supports manual stock-count corrections, apply
`20240006_stock_adjustments.sql` and then
`20240007_server_owned_movement_cursor.sql`. The latter makes movement sync
timestamps server-owned, repairs existing future-dated timestamps, and prevents
legacy local cursors from skipping history by starting a versioned cursor
(which safely reimports movement rows without reapplying their stock effects).
Test both migrations against a staging database and verify the stock movement
constraint, trigger, and exact-count correction before deploying the updated
app. These migrations preserve existing stock totals and do not derive or
rewrite them from historical movements. Migration 20240006 also adds the
products and stock movements tables to the `supabase_realtime` publication
when that publication exists; confirm the updated app receives database change
notifications in staging.
An iOS bundle identifier does not configure the Supabase schema or Android
application ID.

## Production app monitoring

GearStock uses the existing Sentry Flutter integration for crash/error
reporting, sampled performance traces, app sessions, and screen-navigation
traces. Set the Sentry project's Flutter DSN in the local, ignored `.env` file
before building the APK:

```dotenv
SENTRY_DSN=https://<public-key>@<organization>.ingest.sentry.io/<project-id>
```

The DSN is a client-side identifier, not an admin credential; do not put
passwords, auth tokens, or other secrets in it. The SDK is enabled only when
`SENTRY_DSN` starts with `http`. Without it, the app still runs but sends no
Sentry telemetry. Debug builds are labeled `development`; release builds are
labeled `production`. Traces are sampled at 20%, while Sentry's error/crash
reporting remains enabled. Default PII collection is disabled. Navigation
monitoring records the app's fixed route names only; route arguments, signed-in
account identity, and product/supplier/customer data are not attached.
Screenshots, session replay, and free-form user-action tracking are not enabled.

Build and distribute a new release after configuring the DSN:

```sh
flutter build apk --release
```

Installing an update over the existing app preserves its on-device database
when the application ID and Android signing key remain the same. Uninstalling
the app or clearing its storage deletes the local database, including changes
that have not synced yet. Data already synchronized to Supabase remains there
and can be downloaded again after signing in; verify sync has completed before
removing the app from a device.

An APK already installed on a phone cannot be configured remotely: if that APK
was built without a Sentry DSN, it will not start reporting. Users must install
an updated APK built with the DSN. After rollout, use the Sentry project's
Issues view for crashes/errors, Performance for sampled route traces, and
Release Health for sessions; filter events to the `production` environment.
Create an issue alert in Sentry if the team should be notified when new issues
arrive—events appear in the dashboard even when no alert rule is configured.
Verify delivery by installing a production-like build on a test device,
exercising normal navigation, and confirming a controlled test error from a
test/staging build appears in the Sentry project before broad distribution.

Navigation traces and sessions provide operational usage/performance context;
this is not a product-analytics dashboard and does not provide per-user
behavior profiles. Keep the Sentry project access restricted to the development
team and set retention according to the shop's privacy requirements.
