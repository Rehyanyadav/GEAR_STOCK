---
phase: production
plan: 6
wave: 5
depends_on: [1, 2, 3, 4, 5]
files_modified:
  - android/app/build.gradle.kts
  - ios/Runner.xcodeproj/project.pbxproj
  - ios/Runner/Info.plist
  - .gsd/STATE.md
autonomous: false
user_setup:
  - service: apple-signing
    why: "A permanent bundle identifier and valid signing/provisioning assets are owner-specific."
    env_vars: []
    dashboard_config:
      - task: "Provide the approved reverse-DNS iOS bundle identifier and signing/provisioning configuration through the local secure developer setup."
        location: "Apple Developer account / Xcode signing configuration"
  - service: android-signing
    why: "A production application ID and signing keystore are owner-specific."
    env_vars: []
    dashboard_config:
      - task: "Provide the approved reverse-DNS Android application ID and release signing configuration through local secure setup; do not put keystore secrets in source control."
        location: "Android release configuration"

must_haves:
  truths:
    - "The iOS app installs and launches on the connected iPhone from a verified build, or the exact signing/toolchain blocker is recorded."
    - "The Android release configuration no longer claims production readiness while it uses a template ID/debug signing."
    - "No secrets or signing credentials are committed."
  artifacts:
    - "Updated .gsd/STATE.md with exact verification evidence and remaining external blockers"
  key_links:
    - "The objective_c.framework signature failure is diagnosed at the artifact/toolchain boundary before changing packaging behavior."
---

# Plan P.6: Device and Release Validation

<objective>
Resolve the known iOS install-signature failure, validate platform builds/devices, and record remaining owner-only release setup accurately.

Purpose: A locally built app bundle existed, but device install rejected the nested `objective_c.framework`; Android SDK/device validation and production identifiers/signing remain unavailable.
Output: Reproducible build/install evidence and an explicit list of external release requirements.
</objective>

<context>
Load for context:
- `.gsd/ROADMAP.md`
- `.gsd/STATE.md`
- `ios/Runner.xcodeproj/project.pbxproj`
- `android/app/build.gradle.kts`
- `ios/Runner/Info.plist`
</context>

<tasks>
<task type="auto">
  <name>Diagnose nested iOS framework signature and validate clean packaging</name>
  <files>ios/Runner.xcodeproj/project.pbxproj, ios/Runner/Info.plist, .gsd/STATE.md</files>
  <action>
    Reproduce the `objective_c.framework` install failure from a clean build and inspect the embedded framework signature, build phases, codesign settings, and dependency packaging. Correct only the verified root cause, then run build, signature verification, install, launch, and physical scanner permission/feed checks. If blocked by host toolchain/signing rather than project configuration, document exact command output and next owner action.
    AVOID disabling code signing validation, altering dependency binaries, or claiming successful device validation from an outer-app signature check alone.
  </action>
  <verify>`flutter build ios --debug`; verify the embedded framework and full app bundle signatures; install and launch using the available iOS device tooling; record scanner result or precise blocker in `.gsd/STATE.md`.</verify>
  <done>The connected device launches the current build and scanner behavior is verified, or the remaining external blocker is documented with reproducible evidence.</done>
</task>
<task type="auto">
  <name>Apply owner-approved app identifiers and validate Android/release signing</name>
  <files>android/app/build.gradle.kts, ios/Runner.xcodeproj/project.pbxproj, ios/Runner/Info.plist, .gsd/STATE.md</files>
  <action>
    After owner supplies approved reverse-DNS identifiers and local signing configuration, replace template IDs and configure release signing without storing credentials in source. Build Android when SDK/device is available, verify iOS configuration, and produce release candidates only; do not publish to stores.
    AVOID inventing an app ID, committing keystores/profiles/secrets, or representing debug signing as production signing. If owner configuration or Android SDK is still unavailable, leave the corresponding item explicitly blocked.
  </action>
  <verify>`flutter analyze`, `flutter test`, `flutter build appbundle --release` when Android SDK/signing are configured, and signed iOS release build validation when Apple signing is configured. Record commands/results and blockers in `.gsd/STATE.md`.</verify>
  <done>Configured platform identifiers are non-template, release signing is locally supplied and validated, and all unavailable setup is explicitly listed without claiming store readiness.</done>
</task>
</tasks>

<verification>
- [ ] The current iOS artifact is installed/launched or its blocker is evidenced precisely.
- [ ] Android SDK/device/signing availability is accurately reported.
- [ ] No signing secrets are in tracked files.
</verification>

<success_criteria>
- [ ] `flutter analyze` and `flutter test` pass after release-configuration changes.
- [ ] Release readiness is described only to the level proven by signed build and device evidence.
</success_criteria>
