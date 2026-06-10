-- Clean up existing definitions to avoid enum and table conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;

-- Roles enum (admin, operations, sales, hr, viewer)
CREATE TYPE user_role AS ENUM ('admin', 'operations', 'sales', 'hr', 'viewer');

-- Profile table (linked to auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'viewer',
    phone TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Trigger function to automatically create a profile for new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  _full_name text;
  _phone text;
BEGIN
  _full_name := NULLIF(NEW.raw_user_meta_data->>'full_name', '');
  IF _full_name IS NULL THEN
    _full_name := split_part(COALESCE(NEW.email, ''), '@', 1);
  END IF;
  _phone := NULLIF(COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone), '');

  INSERT INTO public.profiles (id, email, full_name, phone, role)
  VALUES (
    NEW.id,
    NEW.email,
    _full_name,
    _phone,
    'viewer'::public.user_role
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Trigger
CREATE OR REPLACE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Helper to check if a user is an admin without policy recursion
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- User Policies
CREATE POLICY "Users can read their own profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
ON public.profiles
FOR UPDATE
USING (auth.uid() = id);

-- Admin Policies
CREATE POLICY "Admins can read all profiles"
ON public.profiles
FOR SELECT
USING (public.is_admin());

CREATE POLICY "Admins can update all profiles"
ON public.profiles
FOR UPDATE
USING (public.is_admin());


