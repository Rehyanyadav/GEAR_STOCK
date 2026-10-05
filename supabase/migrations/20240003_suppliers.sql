-- Migration: Suppliers
-- Apply via Supabase dashboard or supabase CLI: supabase db push

CREATE TABLE IF NOT EXISTS suppliers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  contact_person  text NOT NULL DEFAULT '',
  phone           text NOT NULL DEFAULT '',
  email           text NOT NULL DEFAULT '',
  city            text NOT NULL DEFAULT '',
  gst_number      text,
  lead_time_days  int NOT NULL DEFAULT 0,
  rating          numeric(3,1) NOT NULL DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) DEFAULT auth.uid()
);

ALTER TABLE stock_movements
  ADD CONSTRAINT stock_movements_supplier_id_fkey
  FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL;

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_all_suppliers" ON suppliers
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
