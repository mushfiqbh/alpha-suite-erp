-- HR module: leave types and employee leave requests.
-- The `approval_status` flow is: pending -> approved | rejected.

CREATE OR REPLACE FUNCTION public.can_manage_leave()
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
-- leave_types
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leave_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  days_per_year INTEGER NOT NULL DEFAULT 0,
  paid_leave BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT leave_types_days_per_year_check
    CHECK (days_per_year >= 0)
);

CREATE OR REPLACE FUNCTION public.handle_leave_types_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS leave_types_updated_at ON public.leave_types;
CREATE TRIGGER leave_types_updated_at
BEFORE UPDATE ON public.leave_types
FOR EACH ROW
EXECUTE FUNCTION public.handle_leave_types_updated_at();

ALTER TABLE public.leave_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read leave_types" ON public.leave_types;
CREATE POLICY "HR managers can read leave_types"
ON public.leave_types
FOR SELECT
USING (public.can_manage_leave());

DROP POLICY IF EXISTS "HR managers can insert leave_types" ON public.leave_types;
CREATE POLICY "HR managers can insert leave_types"
ON public.leave_types
FOR INSERT
WITH CHECK (public.can_manage_leave());

DROP POLICY IF EXISTS "HR managers can update leave_types" ON public.leave_types;
CREATE POLICY "HR managers can update leave_types"
ON public.leave_types
FOR UPDATE
USING (public.can_manage_leave())
WITH CHECK (public.can_manage_leave());

DROP POLICY IF EXISTS "HR managers can delete leave_types" ON public.leave_types;
CREATE POLICY "HR managers can delete leave_types"
ON public.leave_types
FOR DELETE
USING (public.can_manage_leave());

-- ---------------------------------------------------------------------------
-- leave_requests
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  leave_type_id UUID NOT NULL REFERENCES public.leave_types(id) ON DELETE RESTRICT,
  from_date DATE NOT NULL,
  to_date DATE NOT NULL,
  total_days NUMERIC(4, 1) NOT NULL DEFAULT 1,
  reason TEXT,
  approval_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT leave_requests_status_check
    CHECK (lower(approval_status) IN ('pending', 'approved', 'rejected')),
  CONSTRAINT leave_requests_dates_check
    CHECK (to_date >= from_date),
  CONSTRAINT leave_requests_total_days_check
    CHECK (total_days > 0)
);

CREATE INDEX IF NOT EXISTS leave_requests_employee_idx
  ON public.leave_requests (employee_id);
CREATE INDEX IF NOT EXISTS leave_requests_leave_type_idx
  ON public.leave_requests (leave_type_id);
CREATE INDEX IF NOT EXISTS leave_requests_status_idx
  ON public.leave_requests (lower(approval_status));
CREATE INDEX IF NOT EXISTS leave_requests_dates_idx
  ON public.leave_requests (from_date, to_date);

CREATE OR REPLACE FUNCTION public.handle_leave_requests_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS leave_requests_updated_at ON public.leave_requests;
CREATE TRIGGER leave_requests_updated_at
BEFORE UPDATE ON public.leave_requests
FOR EACH ROW
EXECUTE FUNCTION public.handle_leave_requests_updated_at();

ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read leave_requests" ON public.leave_requests;
CREATE POLICY "HR managers can read leave_requests"
ON public.leave_requests
FOR SELECT
USING (public.can_manage_leave());

DROP POLICY IF EXISTS "HR managers can insert leave_requests" ON public.leave_requests;
CREATE POLICY "HR managers can insert leave_requests"
ON public.leave_requests
FOR INSERT
WITH CHECK (public.can_manage_leave());

DROP POLICY IF EXISTS "HR managers can update leave_requests" ON public.leave_requests;
CREATE POLICY "HR managers can update leave_requests"
ON public.leave_requests
FOR UPDATE
USING (public.can_manage_leave())
WITH CHECK (public.can_manage_leave());

DROP POLICY IF EXISTS "HR managers can delete leave_requests" ON public.leave_requests;
CREATE POLICY "HR managers can delete leave_requests"
ON public.leave_requests
FOR DELETE
USING (public.can_manage_leave());
