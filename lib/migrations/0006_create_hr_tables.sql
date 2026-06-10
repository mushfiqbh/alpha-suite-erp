-- HR module: departments, designations, and employees.
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
-- departments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.handle_departments_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS departments_updated_at ON public.departments;
CREATE TRIGGER departments_updated_at
BEFORE UPDATE ON public.departments
FOR EACH ROW
EXECUTE FUNCTION public.handle_departments_updated_at();

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read departments" ON public.departments;
CREATE POLICY "HR managers can read departments"
ON public.departments
FOR SELECT
USING (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can insert departments" ON public.departments;
CREATE POLICY "HR managers can insert departments"
ON public.departments
FOR INSERT
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can update departments" ON public.departments;
CREATE POLICY "HR managers can update departments"
ON public.departments
FOR UPDATE
USING (public.can_manage_hr())
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can delete departments" ON public.departments;
CREATE POLICY "HR managers can delete departments"
ON public.departments
FOR DELETE
USING (public.can_manage_hr());

CREATE TABLE IF NOT EXISTS public.designations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  title VARCHAR(100) NOT NULL,
  grade VARCHAR(20),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS designations_title_per_dept_unique
ON public.designations (department_id, lower(title));
CREATE INDEX IF NOT EXISTS designations_department_idx
  ON public.designations (department_id);

CREATE OR REPLACE FUNCTION public.handle_designations_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS designations_updated_at ON public.designations;
CREATE TRIGGER designations_updated_at
BEFORE UPDATE ON public.designations
FOR EACH ROW
EXECUTE FUNCTION public.handle_designations_updated_at();

ALTER TABLE public.designations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read designations" ON public.designations;
CREATE POLICY "HR managers can read designations"
ON public.designations
FOR SELECT
USING (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can insert designations" ON public.designations;
CREATE POLICY "HR managers can insert designations"
ON public.designations
FOR INSERT
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can update designations" ON public.designations;
CREATE POLICY "HR managers can update designations"
ON public.designations
FOR UPDATE
USING (public.can_manage_hr())
WITH CHECK (public.can_manage_hr());

DROP POLICY IF EXISTS "HR managers can delete designations" ON public.designations;
CREATE POLICY "HR managers can delete designations"
ON public.designations
FOR DELETE
USING (public.can_manage_hr());

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
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  designation_id UUID REFERENCES public.designations(id) ON DELETE SET NULL,
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

CREATE INDEX IF NOT EXISTS employees_department_idx
  ON public.employees (department_id);
CREATE INDEX IF NOT EXISTS employees_designation_idx
  ON public.employees (designation_id);
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
