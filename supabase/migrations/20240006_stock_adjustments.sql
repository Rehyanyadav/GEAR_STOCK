-- Add explicit exact-count corrections to the stock movement ledger.
-- This migration preserves existing product totals and movement rows.

ALTER TABLE public.stock_movements
  ADD COLUMN IF NOT EXISTS stock_after integer;

ALTER TABLE public.stock_movements
  ADD COLUMN IF NOT EXISTS synced_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.stock_movements
  DROP CONSTRAINT IF EXISTS stock_movements_type_check,
  DROP CONSTRAINT IF EXISTS stock_movements_quantity_check;

ALTER TABLE public.stock_movements
  ADD CONSTRAINT stock_movements_stock_event_check
  CHECK (
    (
      type IN ('IN', 'OUT')
      AND quantity > 0
      AND stock_after IS NULL
    )
    OR
    (
      type = 'ADJUSTMENT'
      AND quantity <> 0
      AND stock_after IS NOT NULL
      AND stock_after >= 0
    )
  );

CREATE OR REPLACE FUNCTION public.sync_product_stock()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.type = 'IN' THEN
    UPDATE public.products
    SET current_stock = current_stock + NEW.quantity
    WHERE id = NEW.product_id AND shop_id = NEW.shop_id;
  ELSIF NEW.type = 'OUT' THEN
    UPDATE public.products
    SET current_stock = GREATEST(0, current_stock - NEW.quantity)
    WHERE id = NEW.product_id AND shop_id = NEW.shop_id;
  ELSIF NEW.type = 'ADJUSTMENT' THEN
    UPDATE public.products
    SET current_stock = NEW.stock_after
    WHERE id = NEW.product_id AND shop_id = NEW.shop_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE INDEX IF NOT EXISTS stock_movements_shop_synced_id_idx
  ON public.stock_movements (shop_id, synced_at, id);

DO $migration$
DECLARE
  target_table text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    FOREACH target_table IN ARRAY ARRAY['products', 'stock_movements']
    LOOP
      IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = target_table
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          target_table
        );
      END IF;
    END LOOP;
  END IF;
END;
$migration$;
