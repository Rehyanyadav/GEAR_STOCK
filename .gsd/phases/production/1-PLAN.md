---
phase: production
plan: 1
wave: 1
depends_on: []
files_modified:
  - android/app/src/main/res/drawable/launch_background.xml
  - android/app/src/main/res/drawable-v21/launch_background.xml
  - android/app/src/main/res/mipmap-mdpi/ic_launcher.png
  - android/app/src/main/res/mipmap-hdpi/ic_launcher.png
  - android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
  - android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
  - android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
  - ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
  - ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json
  - ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
  - ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
  - ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png
  - ios/Runner/Base.lproj/LaunchScreen.storyboard
  - lib/main.dart
  - lib/widgets/gearstock_splash.dart
  - lib/core/router.dart
  - lib/screens/stock_in_screen.dart
  - lib/screens/stock_out_screen.dart
autonomous: true
user_setup: []

must_haves:
  truths:
    - "The existing orange GearStock gear is used consistently for native launch branding and app icons."
    - "After Flutter starts, a brief reveal and restrained stock-action confirmation respect reduced-motion preferences."
  artifacts:
    - "lib/widgets/gearstock_splash.dart"
  key_links:
    - "Native launch stays static; Flutter owns only the short post-start reveal."
---

# Plan P.1: Brand Launch and Stock Feedback

<objective>
Apply the existing GearStock mark to app icons and native launch surfaces, then add only the previously agreed short startup reveal and stock-action feedback.

Purpose: Replace template/blank launch branding without expanding the 10-screen product scope.
Output: Consistent platform launch assets and accessible, restrained Flutter motion.
</objective>

<context>
Load for context:
- `.gsd/SPEC.md`
- `.gsd/ROADMAP.md`
- `assets/images/gearstock_logo.png`
- `lib/main.dart`
- `lib/core/router.dart`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`
</context>

<tasks>
<task type="auto">
  <name>Replace template app icons and static native launch artwork</name>
  <files>
    android/app/src/main/res/drawable/launch_background.xml
    android/app/src/main/res/drawable-v21/launch_background.xml
    android/app/src/main/res/mipmap-mdpi/ic_launcher.png
    android/app/src/main/res/mipmap-hdpi/ic_launcher.png
    android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
    android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
    android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
    ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
    ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json
    ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
    ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
    ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png
    ios/Runner/Base.lproj/LaunchScreen.storyboard
  </files>
  <action>
    Generate/replace Android launcher icons and the iOS app icon catalog from the existing orange gear asset; place that mark on static native launch backgrounds. Preserve platform-required icon sizes, safe areas, launch constraints, and existing permission/build configuration.
    AVOID adding an icon/splash package or animating native launch assets; no new dependency was approved and native launch surfaces must remain static.
  </action>
  <verify>`flutter build apk --debug` when Android SDK is available; otherwise validate asset catalog JSON and Android XML, then record the SDK blocker. Run `flutter build ios --debug` for iOS asset compilation.</verify>
  <done>Both platform launch surfaces use the GearStock mark and all configured icon variants resolve during platform asset compilation.</done>
</task>
<task type="auto">
  <name>Add reduced-motion startup reveal and stock-action confirmation</name>
  <files>lib/main.dart, lib/widgets/gearstock_splash.dart, lib/core/router.dart, lib/screens/stock_in_screen.dart, lib/screens/stock_out_screen.dart</files>
  <action>
    Add a short post-Flutter gear/liquid reveal using the existing asset, then route to the existing app. Use `MediaQuery.disableAnimations`/platform accessibility preference to skip or simplify motion. Add a restrained confirmation on successful stock-in/out only after the local operation commits.
    AVOID full-screen effects on ordinary navigation, decorative animations in the native splash, new screens, and success feedback before persistence succeeds.
  </action>
  <verify>`flutter analyze lib/main.dart lib/widgets/gearstock_splash.dart lib/core/router.dart lib/screens/stock_in_screen.dart lib/screens/stock_out_screen.dart` and focused widget tests for normal/reduced motion and successful/failed stock action behavior.</verify>
  <done>The startup reveal is brief and bypassed for reduced motion; stock feedback appears only after a committed operation; targeted tests pass.</done>
</task>
</tasks>

<verification>
- [ ] Android and iOS native launch assets compile.
- [ ] Startup and stock feedback preserve reduced-motion behavior and existing navigation.
</verification>

<success_criteria>
- [ ] Existing GearStock branding is used without introducing a dependency.
- [ ] All targeted analysis and tests pass.
</success_criteria>
