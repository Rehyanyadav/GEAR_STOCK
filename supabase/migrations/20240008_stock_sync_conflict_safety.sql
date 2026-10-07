-- Reject exact-count corrections based on stale offline stock values.
-- The UPDATE predicate serializes concurrent corrections on the product row.

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
    WHERE id = NEW.product_id
      AND shop_id = NEW.shop_id
      AND current_stock = NEW.stock_after - NEW.quantity;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'GEARSTOCK_STOCK_ADJUSTMENT_CONFLICT: product stock changed since this count was recorded'
        USING ERRCODE = '40001';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
