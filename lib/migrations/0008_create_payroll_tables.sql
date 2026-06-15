-- HR module: payroll_periods and payrolls.
-- Tracks monthly payroll cycles and per-employee pay details.

CREATE OR REPLACE FUNCTION public.can_manage_payroll()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND role IN ('admin', 'hr')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ---------------------------------------------------------------------------
-- payroll_periods
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payroll_periods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  year INTEGER NOT NULL CHECK (year >= 2000),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'open',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT payroll_periods_status_check
    CHECK (lower(status) IN ('open', 'processing', 'closed')),
  CONSTRAINT payroll_periods_dates_check
    CHECK (end_date >= start_date)
);

CREATE UNIQUE INDEX IF NOT EXISTS payroll_periods_month_year_unique
  ON public.payroll_periods (month, year);
CREATE INDEX IF NOT EXISTS payroll_periods_status_idx
  ON public.payroll_periods (lower(status));

CREATE OR REPLACE FUNCTION public.handle_payroll_periods_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS payroll_periods_updated_at ON public.payroll_periods;
CREATE TRIGGER payroll_periods_updated_at
BEFORE UPDATE ON public.payroll_periods
FOR EACH ROW
EXECUTE FUNCTION public.handle_payroll_periods_updated_at();

ALTER TABLE public.payroll_periods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Payroll managers can read payroll_periods" ON public.payroll_periods;
CREATE POLICY "Payroll managers can read payroll_periods"
ON public.payroll_periods
FOR SELECT
USING (public.can_manage_payroll());

DROP POLICY IF EXISTS "Payroll managers can insert payroll_periods" ON public.payroll_periods;
CREATE POLICY "Payroll managers can insert payroll_periods"
ON public.payroll_periods
FOR INSERT
WITH CHECK (public.can_manage_payroll());

DROP POLICY IF EXISTS "Payroll managers can update payroll_periods" ON public.payroll_periods;
CREATE POLICY "Payroll managers can update payroll_periods"
ON public.payroll_periods
FOR UPDATE
USING (public.can_manage_payroll())
WITH CHECK (public.can_manage_payroll());

DROP POLICY IF EXISTS "Payroll managers can delete payroll_periods" ON public.payroll_periods;
CREATE POLICY "Payroll managers can delete payroll_periods"
ON public.payroll_periods
FOR DELETE
USING (public.can_manage_payroll());

-- ---------------------------------------------------------------------------
-- payrolls
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payrolls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payroll_period_id UUID NOT NULL REFERENCES public.payroll_periods(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  allowance NUMERIC(12, 2) NOT NULL DEFAULT 0,
  overtime NUMERIC(12, 2) NOT NULL DEFAULT 0,
  deduction NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax NUMERIC(12, 2) NOT NULL DEFAULT 0,
  net_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  payment_date DATE,
  payment_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT payrolls_payment_status_check
    CHECK (lower(payment_status) IN ('pending', 'paid', 'cancelled')),
  CONSTRAINT payrolls_salary_check
    CHECK (basic_salary >= 0),
  CONSTRAINT payrolls_allowance_check
    CHECK (allowance >= 0),
  CONSTRAINT payrolls_overtime_check
    CHECK (overtime >= 0),
  CONSTRAINT payrolls_deduction_check
    CHECK (deduction >= 0),
  CONSTRAINT payrolls_tax_check
    CHECK (tax >= 0),
  CONSTRAINT payrolls_net_salary_check
    CHECK (net_salary >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS payrolls_period_employee_unique
  ON public.payrolls (payroll_period_id, employee_id);
CREATE INDEX IF NOT EXISTS payrolls_period_idx
  ON public.payrolls (payroll_period_id);
CREATE INDEX IF NOT EXISTS payrolls_employee_idx
  ON public.payrolls (employee_id);
CREATE INDEX IF NOT EXISTS payrolls_payment_status_idx
  ON public.payrolls (lower(payment_status));

CREATE OR REPLACE FUNCTION public.handle_payrolls_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS payrolls_updated_at ON public.payrolls;
CREATE TRIGGER payrolls_updated_at
BEFORE UPDATE ON public.payrolls
FOR EACH ROW
EXECUTE FUNCTION public.handle_payrolls_updated_at();

ALTER TABLE public.payrolls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Payroll managers can read payrolls" ON public.payrolls;
CREATE POLICY "Payroll managers can read payrolls"
ON public.payrolls
FOR SELECT
USING (public.can_manage_payroll());

DROP POLICY IF EXISTS "Payroll managers can insert payrolls" ON public.payrolls;
CREATE POLICY "Payroll managers can insert payrolls"
ON public.payrolls
FOR INSERT
WITH CHECK (public.can_manage_payroll());

DROP POLICY IF EXISTS "Payroll managers can update payrolls" ON public.payrolls;
CREATE POLICY "Payroll managers can update payrolls"
ON public.payrolls
FOR UPDATE
USING (public.can_manage_payroll())
WITH CHECK (public.can_manage_payroll());

DROP POLICY IF EXISTS "Payroll managers can delete payrolls" ON public.payrolls;
CREATE POLICY "Payroll managers can delete payrolls"
ON public.payrolls
FOR DELETE
USING (public.can_manage_payroll());
