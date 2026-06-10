-- Drop leave & holiday tables (leave types, leave requests, holidays).
-- These features are being removed from the application.

DROP TABLE IF EXISTS public.leave_requests CASCADE;
DROP TABLE IF EXISTS public.leave_types CASCADE;
DROP TABLE IF EXISTS public.holidays CASCADE;

-- Drop helper functions that were created by the original migrations
DROP FUNCTION IF EXISTS public.can_manage_leave() CASCADE;
DROP FUNCTION IF EXISTS public.can_manage_holidays() CASCADE;
