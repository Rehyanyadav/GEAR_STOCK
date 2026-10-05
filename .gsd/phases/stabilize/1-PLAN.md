---
phase: stabilize
plan: 1
wave: 1
title: iOS Camera Permission + Scanner Fix
---

# Plan S.1 — iOS Camera Permission + Real Scanner

## Objective
Fix camera permission on iPhone (the setting never appears in iOS Settings → GearStock),
and make the scanner actually work. This is the #1 reported blocker.

## Root Causes Found
1. `NSCameraUsageDescription` was missing from `Info.plist` (already added in previous fix).
2. `barcode_scanner_screen.dart` never imported or used `MobileScanner` — it was a fake
   animated UI. Real `MobileScannerController` is now in place.
3. **Remaining iOS issue**: `mobile_scanner ^6.0.5` requires iOS 13+ and the
   `ios/Podfile` minimum deployment target may be set to iOS 12.
   The `permission_handler` also needs a `NSCameraUsageDescription` entry in its own
   plist section.

## Tasks

<task type="auto">
  <name>Verify and fix iOS minimum deployment target</name>
  <files>
    ios/Podfile
    ios/Runner.xcodeproj/project.pbxproj
  </files>
  <action>
    1. Open `ios/Podfile` and ensure the first line reads:
       `platform :ios, '13.0'`
       If it says 12.0 or is commented out, change it to 13.0.
    2. In `ios/Runner.xcodeproj/project.pbxproj`, search for
       `IPHONEOS_DEPLOYMENT_TARGET` and set all occurrences to `13.0`.
    3. Do NOT touch any Swift or ObjC source files.
  </action>
  <verify>grep -n "platform :ios" ios/Podfile && grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13" ios/Runner.xcodeproj/project.pbxproj</verify>
  <done>Podfile shows `platform :ios, '13.0'` and pbxproj has IPHONEOS_DEPLOYMENT_TARGET = 13.0 for all targets.</done>
</task>

<task type="auto">
  <name>Add permission_handler iOS entries to Info.plist</name>
  <files>ios/Runner/Info.plist</files>
  <action>
    The `permission_handler` package needs specific plist keys beyond just
    NSCameraUsageDescription. Verify the plist already has:
      - NSCameraUsageDescription (confirmed added)
    Also add if missing:
      - No extra keys needed for camera-only; confirm current plist is correct.

    Additionally, `mobile_scanner` v6 on iOS needs the `Privacy - Camera Usage Description`
    which maps to `NSCameraUsageDescription` — already present.

    Run `pod install` to regenerate the Pods with the new deployment target:
    Run: `cd ios && pod install --repo-update`
  </action>
  <verify>grep "NSCameraUsageDescription" ios/Runner/Info.plist</verify>
  <done>NSCameraUsageDescription present in Info.plist. `pod install` completes without errors.</done>
</task>

## Success Criteria
- [ ] `pod install` completes without errors on iOS 13.0 target
- [ ] App shows camera permission dialog on first scanner open on iPhone
- [ ] GearStock appears in iPhone Settings → Privacy → Camera
- [ ] Barcode scanner opens real camera feed (not gradient background)
