-- HR module: company-wide holiday calendar.
-- `holiday_type` is a free-form label (Public, Religious, Observance, etc.).

CREATE OR REPLACE FUNCTION public.can_manage_holidays()
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
-- holidays
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  holiday_name VARCHAR(150) NOT NULL,
  holiday_date DATE NOT NULL,
  holiday_type VARCHAR(50) NOT NULL DEFAULT 'Public',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS holidays_date_idx
  ON public.holidays (holiday_date);
CREATE INDEX IF NOT EXISTS holidays_type_idx
  ON public.holidays (lower(holiday_type));

CREATE OR REPLACE FUNCTION public.handle_holidays_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS holidays_updated_at ON public.holidays;
CREATE TRIGGER holidays_updated_at
BEFORE UPDATE ON public.holidays
FOR EACH ROW
EXECUTE FUNCTION public.handle_holidays_updated_at();

ALTER TABLE public.holidays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "HR managers can read holidays" ON public.holidays;
CREATE POLICY "HR managers can read holidays"
ON public.holidays
FOR SELECT
USING (public.can_manage_holidays());

DROP POLICY IF EXISTS "HR managers can insert holidays" ON public.holidays;
CREATE POLICY "HR managers can insert holidays"
ON public.holidays
FOR INSERT
WITH CHECK (public.can_manage_holidays());

DROP POLICY IF EXISTS "HR managers can update holidays" ON public.holidays;
CREATE POLICY "HR managers can update holidays"
ON public.holidays
FOR UPDATE
USING (public.can_manage_holidays())
WITH CHECK (public.can_manage_holidays());

DROP POLICY IF EXISTS "HR managers can delete holidays" ON public.holidays;
CREATE POLICY "HR managers can delete holidays"
ON public.holidays
FOR DELETE
USING (public.can_manage_holidays());
