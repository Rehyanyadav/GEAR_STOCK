-- Migration: Stock Movements
-- Apply via Supabase dashboard or supabase CLI: supabase db push

CREATE TABLE IF NOT EXISTS stock_movements (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id       uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  type             text NOT NULL CHECK (type IN ('IN', 'OUT')),
  quantity         int  NOT NULL CHECK (quantity > 0),
  note             text NOT NULL DEFAULT '',
  reference_number text NOT NULL DEFAULT '',
  unit_price       numeric(12,2) NOT NULL DEFAULT 0,
  operator_name    text NOT NULL DEFAULT '',
  supplier_id      uuid,
  created_at       timestamptz NOT NULL DEFAULT now(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) DEFAULT auth.uid()
);

ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_all_stock_movements" ON stock_movements
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Keep product current_stock in sync on Supabase side too
CREATE OR REPLACE FUNCTION sync_product_stock()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.type = 'IN' THEN
    UPDATE products SET current_stock = current_stock + NEW.quantity
    WHERE id = NEW.product_id;
  ELSIF NEW.type = 'OUT' THEN
    UPDATE products SET current_stock = GREATEST(0, current_stock - NEW.quantity)
    WHERE id = NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_product_stock
  AFTER INSERT ON stock_movements
  FOR EACH ROW EXECUTE FUNCTION sync_product_stock();
