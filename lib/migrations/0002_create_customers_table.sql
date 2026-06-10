-- Customer management table for CRM and sales workflows.

CREATE OR REPLACE FUNCTION public.can_manage_customers()
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

CREATE TABLE IF NOT EXISTS public.customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_code VARCHAR(20) NOT NULL UNIQUE,
  customer_type VARCHAR(20) NOT NULL DEFAULT 'company',
  company_name VARCHAR(255),
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  email VARCHAR(255),
  phone VARCHAR(50),
  website VARCHAR(255),
  industry VARCHAR(100),
  billing_address TEXT,
  shipping_address TEXT,
  city VARCHAR(100),
  country VARCHAR(100),
  status VARCHAR(20) NOT NULL DEFAULT 'prospect',
  source VARCHAR(50),
  assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  CONSTRAINT customers_status_check
    CHECK (lower(status) IN ('active', 'inactive', 'prospect', 'lead', 'customer', 'vip'))
);

CREATE OR REPLACE FUNCTION public.handle_customers_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS customers_updated_at ON public.customers;
CREATE TRIGGER customers_updated_at
BEFORE UPDATE ON public.customers
FOR EACH ROW
EXECUTE FUNCTION public.handle_customers_updated_at();

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read customers" ON public.customers;
CREATE POLICY "Authenticated users can read customers"
ON public.customers
FOR SELECT
USING (public.can_manage_customers());

DROP POLICY IF EXISTS "Authenticated users can insert customers" ON public.customers;
CREATE POLICY "Authenticated users can insert customers"
ON public.customers
FOR INSERT
WITH CHECK (public.can_manage_customers());

DROP POLICY IF EXISTS "Authenticated users can update customers" ON public.customers;
CREATE POLICY "Authenticated users can update customers"
ON public.customers
FOR UPDATE
USING (public.can_manage_customers())
WITH CHECK (public.can_manage_customers());

DROP POLICY IF EXISTS "Authenticated users can delete customers" ON public.customers;
CREATE POLICY "Authenticated users can delete customers"
ON public.customers
FOR DELETE
USING (public.can_manage_customers());
