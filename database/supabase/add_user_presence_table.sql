-- Supabase SQL-Migration: eingeloggte Nutzer mit kurzem Heartbeat anzeigen

CREATE TABLE IF NOT EXISTS public.user_presence (
    username text PRIMARY KEY REFERENCES public.users(username) ON DELETE CASCADE,
    last_seen timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Presence is publicly readable" ON public.user_presence;
DROP POLICY IF EXISTS "Anyone can create presence" ON public.user_presence;
DROP POLICY IF EXISTS "Anyone can update presence" ON public.user_presence;
DROP POLICY IF EXISTS "Anyone can delete presence" ON public.user_presence;

CREATE POLICY "Presence is publicly readable"
ON public.user_presence
FOR SELECT
USING (true);

CREATE POLICY "Anyone can create presence"
ON public.user_presence
FOR INSERT
WITH CHECK (length(trim(username)) BETWEEN 1 AND 50);

CREATE POLICY "Anyone can update presence"
ON public.user_presence
FOR UPDATE
USING (true)
WITH CHECK (length(trim(username)) BETWEEN 1 AND 50);

CREATE POLICY "Anyone can delete presence"
ON public.user_presence
FOR DELETE
USING (true);

CREATE INDEX IF NOT EXISTS user_presence_last_seen_idx
ON public.user_presence (last_seen DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_presence TO anon, authenticated;
