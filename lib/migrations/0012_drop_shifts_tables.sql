-- Drop shift-related tables. Department/designation are now free-text fields
-- on the employees table, so the separate shifts and employee_shifts tables
-- are no longer needed.
--
-- This migration:
--  1. Drops the employee_shifts table (shift assignments).
--  2. Drops the shifts table.

DROP TABLE IF EXISTS public.employee_shifts;
DROP TABLE IF EXISTS public.shifts;
