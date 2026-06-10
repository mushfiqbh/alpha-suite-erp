-- Migrate employees table: change department_id and designation_id
-- from foreign-key UUIDs to free-text VARCHAR columns.
--
-- This migration:
--  1. Drops the FK constraints on department_id / designation_id.
--  2. Adds free-text department / designation columns.
--  3. Migrates existing data (copies the name/title from the referenced rows).
--  4. Drops the old FK columns and their indexes.

-- ---------------------------------------------------------------------------
-- 1. Drop FK constraints
-- ---------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.employees
  DROP CONSTRAINT IF EXISTS employees_department_id_fkey;

ALTER TABLE IF EXISTS public.employees
  DROP CONSTRAINT IF EXISTS employees_designation_id_fkey;

-- ---------------------------------------------------------------------------
-- 2. Add new free-text columns
-- ---------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.employees
  ADD COLUMN IF NOT EXISTS department VARCHAR(100);

ALTER TABLE IF EXISTS public.employees
  ADD COLUMN IF NOT EXISTS designation VARCHAR(100);

-- ---------------------------------------------------------------------------
-- 3. Migrate existing data from the referenced tables
-- ---------------------------------------------------------------------------
UPDATE public.employees e
  SET department = d.name
  FROM public.departments d
  WHERE e.department_id IS NOT NULL
    AND e.department_id = d.id
    AND e.department IS NULL;

UPDATE public.employees e
  SET designation = d.title
  FROM public.designations d
  WHERE e.designation_id IS NOT NULL
    AND e.designation_id = d.id
    AND e.designation IS NULL;

-- ---------------------------------------------------------------------------
-- 4. Drop old FK columns and indexes
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS public.employees_department_idx;
DROP INDEX IF EXISTS public.employees_designation_idx;

ALTER TABLE IF EXISTS public.employees
  DROP COLUMN IF EXISTS department_id;

ALTER TABLE IF EXISTS public.employees
  DROP COLUMN IF EXISTS designation_id;
