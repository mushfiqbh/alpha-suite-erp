-- Sales / order management: orders, line items, and payments.
-- Follows the same RLS pattern used by customers and products.

CREATE OR REPLACE FUNCTION public.can_manage_sales()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND role IN ('admin', 'operations', 'sales')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';


-- ---------------------------------------------------------------------------
-- sales_orders
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no VARCHAR(50) UNIQUE NOT NULL DEFAULT public.generate_sales_invoice_no(),

  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,

  order_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  due_date DATE,

  subtotal NUMERIC(18, 2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  shipping_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  grand_total NUMERIC(18, 2) NOT NULL,

  paid_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  due_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

  payment_status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
  sales_status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',

  notes TEXT,

  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  CONSTRAINT sales_orders_payment_status_check
    CHECK (lower(payment_status) IN ('unpaid', 'partial', 'paid', 'refunded', 'cancelled')),
  CONSTRAINT sales_orders_sales_status_check
    CHECK (lower(sales_status) IN ('draft', 'pending', 'completed', 'cancelled', 'refunded')),
  CONSTRAINT sales_orders_grand_total_nonneg
    CHECK (grand_total >= 0)
);

CREATE INDEX IF NOT EXISTS sales_orders_customer_idx
  ON public.sales_orders (customer_id);
CREATE INDEX IF NOT EXISTS sales_orders_order_date_idx
  ON public.sales_orders (order_date DESC);
CREATE INDEX IF NOT EXISTS sales_orders_payment_status_idx
  ON public.sales_orders (lower(payment_status));
CREATE INDEX IF NOT EXISTS sales_orders_sales_status_idx
  ON public.sales_orders (lower(sales_status));


-- ---------------------------------------------------------------------------
-- sales_order_items
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  sales_order_id UUID NOT NULL
    REFERENCES public.sales_orders(id) ON DELETE CASCADE,

  product_id UUID NOT NULL
    REFERENCES public.products(id) ON DELETE RESTRICT,

  quantity NUMERIC(18, 2) NOT NULL,
  unit_price NUMERIC(18, 2) NOT NULL,

  discount_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

  line_total NUMERIC(18, 2) NOT NULL,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  CONSTRAINT sales_order_items_qty_positive
    CHECK (quantity > 0),
  CONSTRAINT sales_order_items_unit_price_nonneg
    CHECK (unit_price >= 0),
  CONSTRAINT sales_order_items_line_total_nonneg
    CHECK (line_total >= 0)
);

CREATE INDEX IF NOT EXISTS sales_order_items_order_idx
  ON public.sales_order_items (sales_order_id);
CREATE INDEX IF NOT EXISTS sales_order_items_product_idx
  ON public.sales_order_items (product_id);


-- ---------------------------------------------------------------------------
-- sales_payments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sales_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  sales_order_id UUID NOT NULL
    REFERENCES public.sales_orders(id) ON DELETE CASCADE,

  payment_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

  amount NUMERIC(18, 2) NOT NULL,

  payment_method VARCHAR(30),
  transaction_no VARCHAR(100),

  remarks TEXT,

  received_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  CONSTRAINT sales_payments_amount_positive
    CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS sales_payments_order_idx
  ON public.sales_payments (sales_order_id);


-- ---------------------------------------------------------------------------
-- updated_at trigger for sales_orders
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_sales_orders_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sales_orders_updated_at ON public.sales_orders;
CREATE TRIGGER sales_orders_updated_at
BEFORE UPDATE ON public.sales_orders
FOR EACH ROW
EXECUTE FUNCTION public.handle_sales_orders_updated_at();


-- ---------------------------------------------------------------------------
-- Invoice number generator: INV-YYYYMMDD-XXXXX
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_sales_invoice_no()
RETURNS text AS $$
DECLARE
  v_date_part text;
  v_seq bigint;
  v_invoice text;
BEGIN
  v_date_part := to_char(now() AT TIME ZONE 'UTC', 'YYYYMMDD');

  SELECT COUNT(*) + 1
    INTO v_seq
  FROM public.sales_orders
  WHERE invoice_no LIKE 'INV-' || v_date_part || '-%';

  v_invoice := 'INV-' || v_date_part || '-' || lpad(v_seq::text, 5, '0');
  RETURN v_invoice;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------------
-- Invoice number trigger: backfill invoice_no when it's explicitly NULL
-- ---------------------------------------------------------------------------
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


-- ---------------------------------------------------------------------------
-- Auto-decrement product stock when a sales order item is inserted.
-- Runs per-row, after the parent order row exists (FK enforces this).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_sales_order_items_stock()
RETURNS trigger AS $$
BEGIN
  UPDATE public.products
    SET stock = GREATEST(stock - NEW.quantity::integer, 0),
        status = CASE
          WHEN (stock - NEW.quantity::integer) <= 0 THEN 'out_of_stock'
          ELSE status
        END,
        updated_at = now()
  WHERE id = NEW.product_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS sales_order_items_stock ON public.sales_order_items;
CREATE TRIGGER sales_order_items_stock
AFTER INSERT ON public.sales_order_items
FOR EACH ROW
EXECUTE FUNCTION public.handle_sales_order_items_stock();


-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.sales_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Sales staff can read sales_orders" ON public.sales_orders;
CREATE POLICY "Sales staff can read sales_orders"
ON public.sales_orders
FOR SELECT
USING (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can insert sales_orders" ON public.sales_orders;
CREATE POLICY "Sales staff can insert sales_orders"
ON public.sales_orders
FOR INSERT
WITH CHECK (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can update sales_orders" ON public.sales_orders;
CREATE POLICY "Sales staff can update sales_orders"
ON public.sales_orders
FOR UPDATE
USING (public.can_manage_sales())
WITH CHECK (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can delete sales_orders" ON public.sales_orders;
CREATE POLICY "Sales staff can delete sales_orders"
ON public.sales_orders
FOR DELETE
USING (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can read sales_order_items" ON public.sales_order_items;
CREATE POLICY "Sales staff can read sales_order_items"
ON public.sales_order_items
FOR SELECT
USING (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can insert sales_order_items" ON public.sales_order_items;
CREATE POLICY "Sales staff can insert sales_order_items"
ON public.sales_order_items
FOR INSERT
WITH CHECK (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can update sales_order_items" ON public.sales_order_items;
CREATE POLICY "Sales staff can update sales_order_items"
ON public.sales_order_items
FOR UPDATE
USING (public.can_manage_sales())
WITH CHECK (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can delete sales_order_items" ON public.sales_order_items;
CREATE POLICY "Sales staff can delete sales_order_items"
ON public.sales_order_items
FOR DELETE
USING (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can read sales_payments" ON public.sales_payments;
CREATE POLICY "Sales staff can read sales_payments"
ON public.sales_payments
FOR SELECT
USING (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can insert sales_payments" ON public.sales_payments;
CREATE POLICY "Sales staff can insert sales_payments"
ON public.sales_payments
FOR INSERT
WITH CHECK (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can update sales_payments" ON public.sales_payments;
CREATE POLICY "Sales staff can update sales_payments"
ON public.sales_payments
FOR UPDATE
USING (public.can_manage_sales())
WITH CHECK (public.can_manage_sales());

DROP POLICY IF EXISTS "Sales staff can delete sales_payments" ON public.sales_payments;
CREATE POLICY "Sales staff can delete sales_payments"
ON public.sales_payments
FOR DELETE
USING (public.can_manage_sales());
