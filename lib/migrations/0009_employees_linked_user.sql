-- Remove reporting_manager (manager_id) column and add linked_user_id
-- to associate an employee record with a profiles (auth user) entry.
-- This allows auto-creating employee profiles when users are assigned
-- operations, hr, or sales roles.

-- Drop the FK and index on the old manager_id column first.
DROP INDEX IF EXISTS public.employees_manager_idx;

ALTER TABLE public.employees
  DROP CONSTRAINT IF EXISTS employees_manager_id_fkey,
  DROP COLUMN IF EXISTS manager_id;

-- Add linked_user_id column.
ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS linked_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS employees_linked_user_idx
  ON public.employees (linked_user_id);

-- ---------------------------------------------------------------------------
-- Function: auto_create_employee_for_role()
-- Called by a trigger on public.profiles AFTER UPDATE of role.
-- When a user's role changes to operations / hr / sales, we automatically
-- create an employee record if one does not already exist for that user.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_create_employee_for_role()
RETURNS trigger AS $$
DECLARE
  v_first_name  VARCHAR(100);
  v_email       VARCHAR(150);
  v_emp_code    VARCHAR(20);
BEGIN
  -- Only act when the role changes to an "employee" role (not admin/viewer).
  IF NEW.role IS DISTINCT FROM OLD.role
     AND NEW.role IN ('operations', 'hr', 'sales')
  THEN
    -- Check if an employee record already exists for this user.
    IF NOT EXISTS (
      SELECT 1 FROM public.employees WHERE linked_user_id = NEW.id
    ) THEN
      -- Derive first_name from full_name.
      v_first_name := COALESCE(
        NULLIF(TRIM(SPLIT_PART(NEW.full_name, ' ', 1)), ''),
        'User'
      );
      v_email := NEW.email;

      -- Generate a unique employee code.
      v_emp_code := 'EMP-' || UPPER(SUBSTR(MD5(NEW.id::TEXT || CLOCK_TIMESTAMP()::TEXT), 1, 6));

      INSERT INTO public.employees (
        employee_code,
        first_name,
        email,
        linked_user_id,
        status
      ) VALUES (
        v_emp_code,
        v_first_name,
        v_email,
        NEW.id,
        'active'
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS trg_auto_create_employee_on_role_change ON public.profiles;
CREATE TRIGGER trg_auto_create_employee_on_role_change
AFTER UPDATE OF role ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.auto_create_employee_for_role();

-- Also fire for INSERT so that when profiles are initially created with a
-- role (e.g. during sign-up flows that set a role), an employee record is
-- created immediately.
DROP TRIGGER IF EXISTS trg_auto_create_employee_on_role_insert ON public.profiles;
CREATE TRIGGER trg_auto_create_employee_on_role_insert
AFTER INSERT ON public.profiles
FOR EACH ROW
WHEN (NEW.role IN ('operations', 'hr', 'sales'))
EXECUTE FUNCTION public.auto_create_employee_for_role();
