-- HR module: employees.
-- These tables are the source of truth for the HR module and are kept
-- separate from `public.profiles` (which tracks application users and roles).

CREATE OR REPLACE FUNCTION public.can_manage_hr()
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
-- employees
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_code VARCHAR(20) NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100),
  email VARCHAR(150),
  phone VARCHAR(20),
  gender VARCHAR(20),
  dob DATE,
  joining_date DATE,
  department VARCHAR(100),
  designation VARCHAR(100),
  manager_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  employment_type VARCHAR(50) NOT NULL DEFAULT 'permanent',
  basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT employees_status_check
    CHECK (lower(status) IN ('active', 'inactive', 'on_leave', 'terminated')),
  CONSTRAINT employees_employment_type_check
    CHECK (lower(employment_type) IN ('permanent', 'contract', 'intern', 'probation', 'part_time')),
  CONSTRAINT employees_gender_check
    CHECK (gender IS NULL OR lower(gender) IN ('male', 'female', 'other', 'prefer_not_to_say')),
  CONSTRAINT employees_salary_check
    CHECK (basic_salary >= 0)
);

CREATE INDEX IF NOT EXISTS employees_manager_idx
  ON public.employees (manager_id);
CREATE INDEX IF NOT EXISTS employees_status_idx
  ON public.employees (lower(status));
CREATE INDEX IF NOT EXISTS employees_name_trgm_idx
  ON public.employees (lower(first_name), lower(last_name));

CREATE OR REPLACE FUNCTION public.handle_employees_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS employees_updated_at ON public.employees;
CREATE TRIGGER employees_updated_at
BEFORE UPDATE ON public.employees
FOR EACH ROW
EXECUTE FUNCTION public.handle_employees_updated_at();

ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read employees" ON public.employees;
CREATE POLICY "HR managers can read employees"
ON public.employees
FOR SELECT
USING (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can insert employees" ON public.employees;
CREATE POLICY "HR managers can insert employees"
ON public.employees
FOR INSERT
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can update employees" ON public.employees;
CREATE POLICY "HR managers can update employees"
ON public.employees
FOR UPDATE
USING (public.can_manage_hr())
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can delete employees" ON public.employees;
CREATE POLICY "HR managers can delete employees"
ON public.employees
FOR DELETE
USING (public.can_manage_hr());
