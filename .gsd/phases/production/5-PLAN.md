---
phase: production
plan: 5
wave: 4
depends_on: [3, 4]
files_modified:
  - supabase/migrations/20240005_product_image_storage.sql
  - lib/features/products/data/product_image_sync_service.dart
  - lib/screens/add_edit_product_screen.dart
  - lib/widgets/product_image.dart
  - test/features/products/product_image_sync_test.dart
autonomous: true
user_setup:
  - service: supabase
    why: "Create/configure the existing product-images bucket and apply shop-scoped Storage policies."
    env_vars: []
    dashboard_config:
      - task: "Confirm the existing `product-images` bucket is private and enable the migration's shop-scoped policies."
        location: "Supabase Dashboard -> Storage"

must_haves:
  truths:
    - "A selected image remains durable locally and uploads to private storage for its authorized shop."
    - "Image read/write requests cannot cross shop boundaries, and account changes cannot reuse another shop's cached image."
    - "Image cache/memory use is bounded and old local files are cleaned only when safe."
  artifacts:
    - "lib/features/products/data/product_image_sync_service.dart"
    - "supabase/migrations/20240005_product_image_storage.sql"
    - "test/features/products/product_image_sync_test.dart"
  key_links:
    - "Outbox/image metadata retains a local image until the authorized upload succeeds."
    - "Storage object paths and Storage policies share the canonical shop ID."
---

# Plan P.5: Private Product Images

<objective>
Complete the existing local image workflow with private, shop-scoped Supabase Storage and safe cache behavior.

Purpose: Product images currently persist in app documents and render from bounded local/network widgets, but there is no upload path.
Output: Private bucket policies, retry-compatible image uploads, and account-aware bounded rendering.
</objective>

<context>
Load for context:
- `.gsd/SPEC.md`
- `.gsd/ROADMAP.md`
- `lib/screens/add_edit_product_screen.dart`
- `lib/widgets/product_image.dart`
- `assets/images/gearstock_logo.png`
- `.gsd/phases/production/3-PLAN.md`
- `.gsd/phases/production/4-PLAN.md`
</context>

<tasks>
<task type="auto">
  <name>Add private shop-scoped Storage policy and upload service</name>
  <files>supabase/migrations/20240005_product_image_storage.sql, lib/features/products/data/product_image_sync_service.dart, test/features/products/product_image_sync_test.dart</files>
  <action>
    Use the already selected `product-images` bucket. Add policies validating shop membership against the shop ID in each object path, implement bounded compressed upload/download metadata using the existing packages, and integrate failed uploads with the durable retry state from plan P.4. Keep local app-owned files until a remote reference is persisted successfully.
    AVOID public bucket access, user-supplied arbitrary object paths, or deleting a local image before upload acknowledgement.
  </action>
  <verify>Test upload success, retry retention, unauthorized shop denial, and object naming; validate the migration with Supabase tooling when configured.</verify>
  <done>Only authorized shop members can read/write that shop's image paths; failed uploads remain retryable and local image data is retained.</done>
</task>
<task type="auto">
  <name>Bound image cache and make account changes invalidate private image state</name>
  <files>lib/screens/add_edit_product_screen.dart, lib/widgets/product_image.dart, test/features/products/product_image_sync_test.dart</files>
  <action>
    Display uploaded private images using the app's authenticated/signed access pattern; cap decoded dimensions and cache growth, clear/invalidate shop-specific cached image entries on shop switch or sign-out, and clean obsolete app-owned files only after confirmed replacement/delete. Preserve current local-file and placeholder rendering.
    AVOID silently substituting an inaccessible private image as a successful saved state or clearing another shop's local image files.
  </action>
  <verify>`flutter test test/features/products/product_image_sync_test.dart test/features/stock/product_image_test.dart` and analyze modified Dart files; test account-switch cache isolation.</verify>
  <done>Remote/local images render after restart, cache use is bounded, and switching shops cannot reveal stale image content.</done>
</task>
</tasks>

<verification>
- [ ] Existing local image persistence remains intact when offline.
- [ ] Bucket access and cache behavior enforce shop isolation.
</verification>

<success_criteria>
- [ ] Image upload and cache tests pass.
- [ ] Bucket remains private and upload retry is durable.
</success_criteria>
