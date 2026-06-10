-- Fix: sales_orders.invoice_no is NOT NULL but no default/trigger
-- was wired up to populate it, so inserts from the app (which don't
-- send invoice_no) violate the constraint.
--
-- Two layers of defense:
--   1. DEFAULT the column to public.generate_sales_invoice_no() so
--      PostgREST inserts that omit the field get a value.
--   2. BEFORE INSERT trigger that backfills invoice_no when it's
--      NULL, so direct SQL / RPCs that explicitly send NULL still
--      get a generated number.

-- Drop and recreate the default so it points at the generator.
ALTER TABLE public.sales_orders
  ALTER COLUMN invoice_no SET DEFAULT public.generate_sales_invoice_no();

-- Trigger: ensure invoice_no is always populated, even if a caller
-- explicitly passes NULL or an empty string.
CREATE OR REPLACE FUNCTION public.handle_sales_orders_invoice_no()
RETURNS trigger AS $$
BEGIN
  IF NEW.invoice_no IS NULL OR btrim(NEW.invoice_no) = '' THEN
    NEW.invoice_no := public.generate_sales_invoice_no();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sales_orders_invoice_no ON public.sales_orders;
CREATE TRIGGER sales_orders_invoice_no
BEFORE INSERT ON public.sales_orders
FOR EACH ROW
EXECUTE FUNCTION public.handle_sales_orders_invoice_no();
