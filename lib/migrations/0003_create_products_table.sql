-- Product catalogue for inventory, sales, and POS workflows.

CREATE OR REPLACE FUNCTION public.can_manage_products()
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

CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku VARCHAR(40) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(100),
  unit VARCHAR(40) DEFAULT 'pcs',
  price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  cost NUMERIC(12, 2) NOT NULL DEFAULT 0,
  stock INTEGER NOT NULL DEFAULT 0,
  reorder_level INTEGER NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  barcode VARCHAR(80),
  supplier VARCHAR(255),
  location VARCHAR(120),
  tax_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
  is_taxable BOOLEAN NOT NULL DEFAULT true,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  CONSTRAINT products_status_check
    CHECK (lower(status) IN ('active', 'inactive', 'draft', 'archived', 'out_of_stock')),
  CONSTRAINT products_price_check
    CHECK (price >= 0),
  CONSTRAINT products_cost_check
    CHECK (cost >= 0),
  CONSTRAINT products_stock_check
    CHECK (stock >= 0)
);

CREATE INDEX IF NOT EXISTS products_category_idx ON public.products (lower(category));
CREATE INDEX IF NOT EXISTS products_status_idx ON public.products (status);
CREATE INDEX IF NOT EXISTS products_name_trgm_idx ON public.products (lower(name));

CREATE OR REPLACE FUNCTION public.handle_products_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS products_updated_at ON public.products;
CREATE TRIGGER products_updated_at
BEFORE UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.handle_products_updated_at();

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read products" ON public.products;
CREATE POLICY "Authenticated users can read products"
ON public.products
FOR SELECT
USING (public.can_manage_products());

DROP POLICY IF EXISTS "Authenticated users can insert products" ON public.products;
CREATE POLICY "Authenticated users can insert products"
ON public.products
FOR INSERT
WITH CHECK (public.can_manage_products());

DROP POLICY IF EXISTS "Authenticated users can update products" ON public.products;
CREATE POLICY "Authenticated users can update products"
ON public.products
FOR UPDATE
USING (public.can_manage_products())
WITH CHECK (public.can_manage_products());

DROP POLICY IF EXISTS "Authenticated users can delete products" ON public.products;
CREATE POLICY "Authenticated users can delete products"
ON public.products
FOR DELETE
USING (public.can_manage_products());
