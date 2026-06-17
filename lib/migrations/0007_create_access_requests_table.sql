-- Access requests module: allows viewer-role users to request role upgrades
-- and admins to approve / reject them.

CREATE TABLE IF NOT EXISTS public.access_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  requested_role VARCHAR(20) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT access_requests_requested_role_check
    CHECK (lower(requested_role) IN ('operations', 'hr', 'sales')),
  CONSTRAINT access_requests_status_check
    CHECK (lower(status) IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS access_requests_user_idx
  ON public.access_requests (user_id);
CREATE INDEX IF NOT EXISTS access_requests_status_idx
  ON public.access_requests (lower(status));

CREATE OR REPLACE FUNCTION public.handle_access_requests_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS access_requests_updated_at ON public.access_requests;
CREATE TRIGGER access_requests_updated_at
BEFORE UPDATE ON public.access_requests
FOR EACH ROW
EXECUTE FUNCTION public.handle_access_requests_updated_at();

ALTER TABLE public.access_requests ENABLE ROW LEVEL SECURITY;

-- Users can read their own requests.
DROP POLICY IF EXISTS "Users can read own requests" ON public.access_requests;
CREATE POLICY "Users can read own requests"
ON public.access_requests
FOR SELECT
USING (auth.uid() = user_id);

-- Admins can read all requests.
DROP POLICY IF EXISTS "Admins can read all requests" ON public.access_requests;
CREATE POLICY "Admins can read all requests"
ON public.access_requests
FOR SELECT
USING (EXISTS (
  SELECT 1 FROM public.profiles
  WHERE id = auth.uid() AND role = 'admin'
));

-- Any authenticated user can insert a request for themselves.
DROP POLICY IF EXISTS "Users can insert own requests" ON public.access_requests;
CREATE POLICY "Users can insert own requests"
ON public.access_requests
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Only admins can update (approve / reject) requests.
DROP POLICY IF EXISTS "Admins can update requests" ON public.access_requests;
CREATE POLICY "Admins can update requests"
ON public.access_requests
FOR UPDATE
USING (EXISTS (
  SELECT 1 FROM public.profiles
  WHERE id = auth.uid() AND role = 'admin'
));
