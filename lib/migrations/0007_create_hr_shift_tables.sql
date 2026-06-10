-- HR module: shift definitions and per-employee shift assignments.
-- Times are stored as plain text in 24-hour "HH:MM[:SS]" form so the
-- application can keep locale-agnostic formatting and PostgREST can
-- compare them without timezone interpretation.

-- ---------------------------------------------------------------------------
-- shifts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_name VARCHAR(100) NOT NULL UNIQUE,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  grace_minutes INTEGER NOT NULL DEFAULT 0,
  working_hours NUMERIC(4, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT shifts_grace_minutes_check
    CHECK (grace_minutes >= 0),
  CONSTRAINT shifts_working_hours_check
    CHECK (working_hours >= 0 AND working_hours <= 24)
);

CREATE OR REPLACE FUNCTION public.handle_shifts_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS shifts_updated_at ON public.shifts;
CREATE TRIGGER shifts_updated_at
BEFORE UPDATE ON public.shifts
FOR EACH ROW
EXECUTE FUNCTION public.handle_shifts_updated_at();

ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read shifts" ON public.shifts;
CREATE POLICY "HR managers can read shifts"
ON public.shifts
FOR SELECT
USING (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can insert shifts" ON public.shifts;
CREATE POLICY "HR managers can insert shifts"
ON public.shifts
FOR INSERT
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can update shifts" ON public.shifts;
CREATE POLICY "HR managers can update shifts"
ON public.shifts
FOR UPDATE
USING (public.can_manage_hr())
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can delete shifts" ON public.shifts;
CREATE POLICY "HR managers can delete shifts"
ON public.shifts
FOR DELETE
USING (public.can_manage_hr());

-- ---------------------------------------------------------------------------
-- employee_shifts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.employee_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  shift_id UUID NOT NULL REFERENCES public.shifts(id) ON DELETE CASCADE,
  effective_from DATE NOT NULL,
  effective_to DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT employee_shifts_dates_check
    CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE INDEX IF NOT EXISTS employee_shifts_employee_idx
  ON public.employee_shifts (employee_id);
CREATE INDEX IF NOT EXISTS employee_shifts_shift_idx
  ON public.employee_shifts (shift_id);
CREATE INDEX IF NOT EXISTS employee_shifts_effective_idx
  ON public.employee_shifts (effective_from, effective_to);

CREATE OR REPLACE FUNCTION public.handle_employee_shifts_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS employee_shifts_updated_at ON public.employee_shifts;
CREATE TRIGGER employee_shifts_updated_at
BEFORE UPDATE ON public.employee_shifts
FOR EACH ROW
EXECUTE FUNCTION public.handle_employee_shifts_updated_at();

ALTER TABLE public.employee_shifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read employee_shifts" ON public.employee_shifts;
CREATE POLICY "HR managers can read employee_shifts"
ON public.employee_shifts
FOR SELECT
USING (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can insert employee_shifts" ON public.employee_shifts;
CREATE POLICY "HR managers can insert employee_shifts"
ON public.employee_shifts
FOR INSERT
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can update employee_shifts" ON public.employee_shifts;
CREATE POLICY "HR managers can update employee_shifts"
ON public.employee_shifts
FOR UPDATE
USING (public.can_manage_hr())
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can delete employee_shifts" ON public.employee_shifts;
CREATE POLICY "HR managers can delete employee_shifts"
ON public.employee_shifts
FOR DELETE
USING (public.can_manage_hr());
