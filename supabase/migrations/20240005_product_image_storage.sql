INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DO $$
BEGIN
  IF NOT COALESCE((
    SELECT r.relrowsecurity
    FROM pg_class r
    JOIN pg_namespace n ON n.oid = r.relnamespace
    WHERE n.nspname = 'storage'
      AND r.relname = 'objects'
  ), false) THEN
    RAISE EXCEPTION
      'Row-level security must be enabled on storage.objects by the Supabase platform before applying GearStock image policies';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.gearstock_can_access_product_image(object_name text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  shop_prefix text;
  product_prefix text;
BEGIN
  shop_prefix := split_part(object_name, '/', 1);
  product_prefix := split_part(object_name, '/', 2);
  IF shop_prefix !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    OR product_prefix !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN false;
  END IF;
  RETURN public.is_gearstock_shop_member(shop_prefix::uuid)
    AND EXISTS (
      SELECT 1
      FROM products
      WHERE id = product_prefix::uuid
        AND shop_id = shop_prefix::uuid
    );
END;
$$;

DROP POLICY IF EXISTS gearstock_product_images_scope ON storage.objects;
CREATE POLICY gearstock_product_images_scope ON storage.objects
  AS RESTRICTIVE
  FOR ALL TO public
  USING (
    bucket_id <> 'product-images'
    OR public.gearstock_can_access_product_image(name)
  )
  WITH CHECK (
    bucket_id <> 'product-images'
    OR public.gearstock_can_access_product_image(name)
  );

DROP POLICY IF EXISTS gearstock_product_images_read ON storage.objects;
DROP POLICY IF EXISTS gearstock_product_images_insert ON storage.objects;
DROP POLICY IF EXISTS gearstock_product_images_update ON storage.objects;
DROP POLICY IF EXISTS gearstock_product_images_delete ON storage.objects;

CREATE POLICY gearstock_product_images_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.gearstock_can_access_product_image(name)
  );
CREATE POLICY gearstock_product_images_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'product-images'
    AND public.gearstock_can_access_product_image(name)
  );
CREATE POLICY gearstock_product_images_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.gearstock_can_access_product_image(name)
  )
  WITH CHECK (
    bucket_id = 'product-images'
    AND public.gearstock_can_access_product_image(name)
  );
CREATE POLICY gearstock_product_images_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.gearstock_can_access_product_image(name)
  );

GRANT EXECUTE ON FUNCTION public.gearstock_can_access_product_image(text)
  TO authenticated;
