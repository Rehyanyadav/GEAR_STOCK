-- Keep untrusted clients from changing the timestamp used by movement sync
-- cursors. Existing future-dated rows are normalized before the trigger exists.

UPDATE public.stock_movements
SET synced_at = now()
WHERE synced_at > now();

CREATE OR REPLACE FUNCTION public.gearstock_enforce_movement_sync_time()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.synced_at := clock_timestamp();
  ELSIF NEW.synced_at IS DISTINCT FROM OLD.synced_at THEN
    NEW.synced_at := OLD.synced_at;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gearstock_enforce_movement_sync_time
  ON public.stock_movements;

CREATE TRIGGER trg_gearstock_enforce_movement_sync_time
BEFORE INSERT OR UPDATE ON public.stock_movements
FOR EACH ROW
EXECUTE FUNCTION public.gearstock_enforce_movement_sync_time();

CREATE OR REPLACE FUNCTION public.gearstock_block_movement_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'stock_movements are append-only; create a compensating ADJUSTMENT instead of mutating or deleting movement history';
END;
$$;

DROP TRIGGER IF EXISTS trg_gearstock_block_movement_mutation
  ON public.stock_movements;

CREATE TRIGGER trg_gearstock_block_movement_mutation
BEFORE UPDATE OR DELETE ON public.stock_movements
FOR EACH ROW
EXECUTE FUNCTION public.gearstock_block_movement_mutation();
