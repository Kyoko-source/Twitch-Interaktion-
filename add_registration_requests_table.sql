-- Supabase SQL-Migration: Admin-genehmigte Registrierung mit Einmalcode

CREATE TABLE IF NOT EXISTS public.registration_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username text NOT NULL,
    password_hash text NOT NULL,
    approval_code_hash text,
    status text NOT NULL DEFAULT 'pending',
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    approved_at timestamp with time zone,
    denied_at timestamp with time zone,
    used_at timestamp with time zone,
    CONSTRAINT registration_requests_status_check
        CHECK (status IN ('pending', 'approved', 'denied', 'used'))
);

CREATE INDEX IF NOT EXISTS registration_requests_username_idx
    ON public.registration_requests (username);

CREATE INDEX IF NOT EXISTS registration_requests_status_idx
    ON public.registration_requests (status);
