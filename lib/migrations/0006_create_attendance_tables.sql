-- HR module: daily attendance and raw punch logs.
-- Times are stored as TIMESTAMP WITH TIME ZONE so the application can
-- reason about exact moments regardless of the device's local clock.

CREATE OR REPLACE FUNCTION public.can_manage_attendance()
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
-- attendance (one row per employee per day)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  attendance_date DATE NOT NULL,
  check_in TIMESTAMP WITH TIME ZONE,
  check_out TIMESTAMP WITH TIME ZONE,
  work_hours NUMERIC(5, 2) NOT NULL DEFAULT 0,
  late_minutes INTEGER NOT NULL DEFAULT 0,
  overtime_hours NUMERIC(5, 2) NOT NULL DEFAULT 0,
  attendance_status VARCHAR(20) NOT NULL DEFAULT 'Present',
  remarks TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT attendance_status_check
    CHECK (lower(attendance_status) IN
      ('present', 'absent', 'late', 'half_day', 'holiday', 'weekend', 'leave')),
  CONSTRAINT attendance_work_hours_check
    CHECK (work_hours >= 0),
  CONSTRAINT attendance_late_minutes_check
    CHECK (late_minutes >= 0),
  CONSTRAINT attendance_overtime_hours_check
    CHECK (overtime_hours >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS attendance_employee_date_unique
  ON public.attendance (employee_id, attendance_date);
CREATE INDEX IF NOT EXISTS attendance_date_idx
  ON public.attendance (attendance_date);
CREATE INDEX IF NOT EXISTS attendance_status_idx
  ON public.attendance (lower(attendance_status));

CREATE OR REPLACE FUNCTION public.handle_attendance_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS attendance_updated_at ON public.attendance;
CREATE TRIGGER attendance_updated_at
BEFORE UPDATE ON public.attendance
FOR EACH ROW
EXECUTE FUNCTION public.handle_attendance_updated_at();

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read attendance" ON public.attendance;
CREATE POLICY "HR managers can read attendance"
ON public.attendance
FOR SELECT
USING (public.can_manage_attendance());

DROP POLICY IF EXISTS "HR managers can insert attendance" ON public.attendance;
CREATE POLICY "HR managers can insert attendance"
ON public.attendance
FOR INSERT
WITH CHECK (public.can_manage_attendance());

DROP POLICY IF EXISTS "HR managers can update attendance" ON public.attendance;
CREATE POLICY "HR managers can update attendance"
ON public.attendance
FOR UPDATE
USING (public.can_manage_attendance())
WITH CHECK (public.can_manage_attendance());

DROP POLICY IF EXISTS "HR managers can delete attendance" ON public.attendance;
CREATE POLICY "HR managers can delete attendance"
ON public.attendance
FOR DELETE
USING (public.can_manage_attendance());

-- ---------------------------------------------------------------------------
-- attendance_logs (raw punch in/out events)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  log_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  log_type VARCHAR(20) NOT NULL,
  device_id UUID,
  location VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT attendance_logs_type_check
    CHECK (lower(log_type) IN ('check_in', 'check_out', 'break_start', 'break_end'))
);

CREATE INDEX IF NOT EXISTS attendance_logs_employee_idx
  ON public.attendance_logs (employee_id);
CREATE INDEX IF NOT EXISTS attendance_logs_log_time_idx
  ON public.attendance_logs (log_time);
CREATE INDEX IF NOT EXISTS attendance_logs_type_idx
  ON public.attendance_logs (lower(log_type));

ALTER TABLE public.attendance_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read attendance_logs" ON public.attendance_logs;
CREATE POLICY "HR managers can read attendance_logs"
ON public.attendance_logs
FOR SELECT
USING (public.can_manage_attendance());

DROP POLICY IF EXISTS "HR managers can insert attendance_logs" ON public.attendance_logs;
CREATE POLICY "HR managers can insert attendance_logs"
ON public.attendance_logs
FOR INSERT
WITH CHECK (public.can_manage_attendance());

DROP POLICY IF EXISTS "HR managers can update attendance_logs" ON public.attendance_logs;
CREATE POLICY "HR managers can update attendance_logs"
ON public.attendance_logs
FOR UPDATE
USING (public.can_manage_attendance())
WITH CHECK (public.can_manage_attendance());

DROP POLICY IF EXISTS "HR managers can delete attendance_logs" ON public.attendance_logs;
CREATE POLICY "HR managers can delete attendance_logs"
ON public.attendance_logs
FOR DELETE
USING (public.can_manage_attendance());
