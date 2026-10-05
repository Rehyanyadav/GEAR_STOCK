-- Migration: Products & Categories
-- Apply via Supabase dashboard (SQL Editor) or supabase CLI: supabase db push

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Categories ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_all_categories" ON categories
  TO authenticated
  USING (true)
  WITH CHECK (true);
-- Note: categories are shop-global (no per-user ownership needed),
-- but access is still restricted to authenticated users via Supabase Auth.

-- ── Products ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sku             text UNIQUE NOT NULL,
  name            text NOT NULL,
  description     text,
  category_id     uuid REFERENCES categories(id) ON DELETE SET NULL,
  brand           text NOT NULL DEFAULT '',
  cost_price      numeric(12,2) NOT NULL CHECK (cost_price >= 0),
  selling_price   numeric(12,2) NOT NULL CHECK (selling_price >= 0),
  current_stock   int NOT NULL DEFAULT 0 CHECK (current_stock >= 0),
  min_stock       int NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
  shelf_location  text NOT NULL DEFAULT '',
  image_url       text,
  barcode         text,
  supplier_name   text NOT NULL DEFAULT '',
  is_deleted      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) DEFAULT auth.uid()
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Users can only see and modify their own shop's products
CREATE POLICY "owner_all_products" ON products
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Auto-update updated_at on any row change
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
