# Shared-shop access

The `20240004_shared_shops.sql` migration creates one default shop for each
existing and newly-created user. Product, category, supplier, and movement
policies grant access only to members of the row's shop.

## Adding a teammate

An invited account can be assigned to an existing shop by setting the
trusted `gearstock_shop_id` value in that user's Supabase `app_metadata`
before the account is created. The auth trigger then creates a staff
membership instead of a second default shop. `app_metadata` must only be
written by an administrator; never accept a shop ID from client-controlled
user metadata.

For an account that already exists, an administrator must remove its
auto-created membership in the Supabase dashboard and add a `staff`
membership for the target shop. The account's separate empty default shop
can then be removed if it has no business rows.

### Repair an owner account missing its membership

The sync runner resolves the signed-in user's shop through
`shop_memberships`. If an existing account has exactly one shop where it is
the owner but no membership row, an administrator can restore that expected
owner membership in SQL Editor. Replace the email locally; do not send it in
chat. This statement is idempotent for accounts that already have a
membership:

```sql
INSERT INTO public.shop_memberships (shop_id, user_id, role)
SELECT s.id, s.owner_user_id, 'owner'
FROM public.shops s
JOIN auth.users u ON u.id = s.owner_user_id
WHERE lower(u.email) = lower('YOUR_SIGN_IN_EMAIL')
  AND NOT EXISTS (
    SELECT 1
    FROM public.shop_memberships m
    WHERE m.user_id = s.owner_user_id
  )
ON CONFLICT (user_id) DO NOTHING;
```

Only use this for an account verified to own exactly one shop. Then rerun
the read-only membership count query and confirm it returns `1`. Restart
GearStock or wait for its scheduled outbox retry; verify the pending count
clears and the test row appears in that shop.

The owner can manage memberships using Supabase's admin controls. Membership
rows are not editable from the GearStock client UI.

## Applying the migrations

Apply the existing migrations in order, then apply:

1. `supabase/migrations/20240004_shared_shops.sql`
2. `supabase/migrations/20240005_product_image_storage.sql`

The tenancy migration intentionally fails if a business record cannot be
associated with an existing user or if a category has no product using it.
Resolve those rows explicitly before retrying. The product image bucket is
private. Supabase manages `storage.objects` and normally has row-level
security enabled on that table already. The migration checks this prerequisite
without attempting to alter the managed table; object paths must use
`<shop-uuid>/<product-uuid>/<filename>`.

The configured project initially returned missing `shop_id`, `shops`, and
`shop_memberships` on 2026-10-04. After the user ran SQL in the Dashboard,
read-only PostgREST checks confirmed those shop tables/columns are present.
The user also reported that migration 20240005 completed successfully.
The user then confirmed `storage.objects` has RLS enabled and five
`gearstock_product_images_*` policies. Still verify signed-in app upload and
cross-shop denial before relying on private image access.

Before changing a populated project, use the Supabase Dashboard SQL Editor to
inspect the data and take a database backup using the backup/export mechanism
available for the project. The following read-only preflight reports row
counts; it does not prove those rows belong to a valid shop:

```sql
SELECT 'products' AS table_name, count(*) AS row_count FROM public.products
UNION ALL
SELECT 'suppliers', count(*) FROM public.suppliers
UNION ALL
SELECT 'stock_movements', count(*) FROM public.stock_movements
UNION ALL
SELECT 'categories', count(*) FROM public.categories;

SELECT 'products' AS table_name, count(*) AS unmapped_owner_rows
FROM public.products p
LEFT JOIN auth.users u ON u.id = p.user_id
WHERE u.id IS NULL
UNION ALL
SELECT 'suppliers', count(*)
FROM public.suppliers s
LEFT JOIN auth.users u ON u.id = s.user_id
WHERE u.id IS NULL;

SELECT c.id, c.name
FROM public.categories c
LEFT JOIN public.products p ON p.category_id = c.id
WHERE p.id IS NULL;
```

The tenancy migration intentionally aborts if it cannot map records to users
or finds unused categories. Resolve any findings and retain a backup before
running it. With the CLI unavailable, apply only the confirmed-missing SQL
files, one at a time and in order, through the SQL Editor: run all of
`20240004_shared_shops.sql`, then all of
`20240005_product_image_storage.sql`. Do not run the earlier migrations again
on this project.

After deployment, sign into GearStock and create a clearly identifiable test
product while online. Confirm the sync status returns to idle with zero
pending changes and that the product is visible in the Supabase `products`
table. Test an offline change and reconnection before relying on the setup for
shop inventory. The app's old shared local database is not automatically
imported into the current per-account database; preserve it until that
separate import is completed and verified.

### Interpreting sync status safely

The app reports a missing network connection separately from a failed
Supabase request. A `ConnectionClosed`/connection-closed failure means the
request did not complete; it is not proof that the phone is offline or that the
server rejected the write. The outbox retains unacknowledged changes and retries
with bounded backoff, and connectivity restoration also wakes sync.

When troubleshooting, record the exact status tooltip and whether pending
changes remain. Do not uninstall the app, clear its storage, delete the old
`gearstock` database, or rerun migrations while any local changes are pending.
Do not send passwords, API keys, access tokens, or inventory rows in a support
message. A public/anonymous health or schema request only proves endpoint
reachability; it does not prove authenticated membership, writes, or shop
isolation.

The app uses a separate OS-sandboxed local database per signed-in account.
Supabase remains the shared-shop source for data exchanged between members.
The local PostgreSQL migration checks are not a substitute for applying the
migrations and validating policies against the configured Supabase project.

The app's sync runner requires migrations `20240004_shared_shops.sql` and
`20240005_product_image_storage.sql`. If PostgREST reports that `shop_id`,
`shops`, or `shop_memberships` is missing, shared-shop sync is not ready.
Back up and inspect existing remote data before applying the tenancy
backfill; do not apply the migration blindly to a populated project.
