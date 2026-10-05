-- Shared-shop tenancy. Existing records are assigned to the shop owned by
-- their current user; existing category values are copied into each shop
-- that uses them before the old global rows are removed.

CREATE TABLE shops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  owner_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE shop_memberships (
  shop_id uuid NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('owner', 'staff')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (shop_id, user_id)
);

INSERT INTO shops (owner_user_id, name)
SELECT id, COALESCE(
  NULLIF(raw_user_meta_data->>'shop_name', ''),
  NULLIF(email, ''),
  'GearStock shop'
)
FROM auth.users
ON CONFLICT (owner_user_id) DO NOTHING;

INSERT INTO shop_memberships (shop_id, user_id, role)
SELECT id, owner_user_id, 'owner'
FROM shops
ON CONFLICT (user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.gearstock_provision_shop()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_shop_id uuid;
  invited_shop_id uuid;
BEGIN
  invited_shop_id := NULLIF(
    NEW.raw_app_meta_data->>'gearstock_shop_id',
    ''
  )::uuid;

  IF invited_shop_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM shops WHERE id = invited_shop_id) THEN
      RAISE EXCEPTION 'Invited GearStock shop does not exist';
    END IF;
    INSERT INTO shop_memberships (shop_id, user_id, role)
    VALUES (invited_shop_id, NEW.id, 'staff');
    RETURN NEW;
  END IF;

  INSERT INTO shops (name, owner_user_id)
  VALUES (
    COALESCE(
      NULLIF(NEW.raw_user_meta_data->>'shop_name', ''),
      NULLIF(NEW.email, ''),
      'GearStock shop'
    ),
    NEW.id
  )
  RETURNING id INTO new_shop_id;

  INSERT INTO shop_memberships (shop_id, user_id, role)
  VALUES (new_shop_id, NEW.id, 'owner');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_gearstock_provision_shop
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.gearstock_provision_shop();

ALTER TABLE products ADD COLUMN shop_id uuid REFERENCES shops(id);
ALTER TABLE suppliers ADD COLUMN shop_id uuid REFERENCES shops(id);
ALTER TABLE stock_movements ADD COLUMN shop_id uuid REFERENCES shops(id);
ALTER TABLE categories ADD COLUMN shop_id uuid REFERENCES shops(id);

UPDATE products p
SET shop_id = m.shop_id
FROM shop_memberships m
WHERE m.user_id = p.user_id;

UPDATE suppliers s
SET shop_id = m.shop_id
FROM shop_memberships m
WHERE m.user_id = s.user_id;

UPDATE stock_movements sm
SET shop_id = p.shop_id
FROM products p
WHERE p.id = sm.product_id;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM products WHERE shop_id IS NULL
    UNION ALL
    SELECT 1 FROM suppliers WHERE shop_id IS NULL
    UNION ALL
    SELECT 1 FROM stock_movements WHERE shop_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'GearStock tenancy migration could not map every business row to an existing auth user/shop';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM categories c
    WHERE NOT EXISTS (
      SELECT 1 FROM products p WHERE p.category_id = c.id
    )
  ) THEN
    RAISE EXCEPTION
      'GearStock tenancy migration found unused categories with no shop owner; assign or remove them before retrying';
  END IF;
END;
$$;

CREATE TEMP TABLE gearstock_category_shop_map (
  old_category_id uuid NOT NULL,
  new_category_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  PRIMARY KEY (old_category_id, shop_id)
);

ALTER TABLE categories DROP CONSTRAINT IF EXISTS categories_name_key;

INSERT INTO gearstock_category_shop_map (
  old_category_id,
  new_category_id,
  shop_id
)
SELECT c.id, gen_random_uuid(), p.shop_id
FROM categories c
JOIN products p ON p.category_id = c.id
GROUP BY c.id, p.shop_id;

INSERT INTO categories (id, name, shop_id)
SELECT map.new_category_id, old_category.name, map.shop_id
FROM gearstock_category_shop_map map
JOIN categories old_category ON old_category.id = map.old_category_id;

UPDATE products p
SET category_id = map.new_category_id
FROM gearstock_category_shop_map map
WHERE p.category_id = map.old_category_id
  AND p.shop_id = map.shop_id;

DELETE FROM categories WHERE shop_id IS NULL;

ALTER TABLE products ALTER COLUMN shop_id SET NOT NULL;
ALTER TABLE suppliers ALTER COLUMN shop_id SET NOT NULL;
ALTER TABLE stock_movements ALTER COLUMN shop_id SET NOT NULL;
ALTER TABLE categories ALTER COLUMN shop_id SET NOT NULL;

ALTER TABLE products DROP CONSTRAINT IF EXISTS products_sku_key;
ALTER TABLE products ADD CONSTRAINT products_shop_sku_key UNIQUE (shop_id, sku);
ALTER TABLE categories
  ADD CONSTRAINT categories_shop_name_key UNIQUE (shop_id, name);

CREATE OR REPLACE FUNCTION public.is_gearstock_shop_member(target_shop_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM shop_memberships membership
    WHERE membership.shop_id = target_shop_id
      AND membership.user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_gearstock_shop_owner(target_shop_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM shop_memberships membership
    WHERE membership.shop_id = target_shop_id
      AND membership.user_id = auth.uid()
      AND membership.role = 'owner'
  );
$$;

CREATE OR REPLACE FUNCTION public.gearstock_validate_product_shop()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM categories category
    WHERE category.id = NEW.category_id
      AND category.shop_id = NEW.shop_id
  ) THEN
    RAISE EXCEPTION 'Product category must belong to the same shop';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_gearstock_validate_product_shop
BEFORE INSERT OR UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION public.gearstock_validate_product_shop();

CREATE OR REPLACE FUNCTION public.gearstock_validate_movement_shop()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  product_shop_id uuid;
  supplier_shop_id uuid;
BEGIN
  SELECT shop_id INTO product_shop_id
  FROM products
  WHERE id = NEW.product_id;
  IF product_shop_id IS NULL OR product_shop_id <> NEW.shop_id THEN
    RAISE EXCEPTION 'Stock movement product must belong to the same shop';
  END IF;

  IF NEW.supplier_id IS NOT NULL THEN
    SELECT shop_id INTO supplier_shop_id
    FROM suppliers
    WHERE id = NEW.supplier_id;
    IF supplier_shop_id IS NULL OR supplier_shop_id <> NEW.shop_id THEN
      RAISE EXCEPTION 'Stock movement supplier must belong to the same shop';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_gearstock_validate_movement_shop
BEFORE INSERT OR UPDATE ON stock_movements
FOR EACH ROW EXECUTE FUNCTION public.gearstock_validate_movement_shop();

ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS owner_all_categories ON categories;
DROP POLICY IF EXISTS owner_all_products ON products;
DROP POLICY IF EXISTS owner_all_suppliers ON suppliers;
DROP POLICY IF EXISTS owner_all_stock_movements ON stock_movements;

CREATE POLICY shops_member_read ON shops
  FOR SELECT TO authenticated
  USING (public.is_gearstock_shop_member(id));
CREATE POLICY memberships_member_read ON shop_memberships
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_gearstock_shop_owner(shop_id)
  );
CREATE POLICY memberships_owner_manage ON shop_memberships
  FOR ALL TO authenticated
  USING (public.is_gearstock_shop_owner(shop_id))
  WITH CHECK (public.is_gearstock_shop_owner(shop_id));

CREATE POLICY categories_shop_access ON categories
  FOR ALL TO authenticated
  USING (public.is_gearstock_shop_member(shop_id))
  WITH CHECK (public.is_gearstock_shop_member(shop_id));
CREATE POLICY products_shop_access ON products
  FOR ALL TO authenticated
  USING (public.is_gearstock_shop_member(shop_id))
  WITH CHECK (public.is_gearstock_shop_member(shop_id));
CREATE POLICY suppliers_shop_access ON suppliers
  FOR ALL TO authenticated
  USING (public.is_gearstock_shop_member(shop_id))
  WITH CHECK (public.is_gearstock_shop_member(shop_id));
CREATE POLICY stock_movements_shop_access ON stock_movements
  FOR ALL TO authenticated
  USING (public.is_gearstock_shop_member(shop_id))
  WITH CHECK (public.is_gearstock_shop_member(shop_id));

GRANT SELECT ON shops, shop_memberships TO authenticated;
GRANT INSERT, UPDATE, DELETE ON shop_memberships TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_gearstock_shop_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_gearstock_shop_owner(uuid) TO authenticated;
