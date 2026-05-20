-- Supabase SQL-Migration: Emoji-Reaktionen fuer die Hall of Fame

CREATE TABLE IF NOT EXISTS public.creative_gallery_reactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    art_id uuid NOT NULL REFERENCES public.creative_gallery(id) ON DELETE CASCADE,
    username text NOT NULL,
    emoji text NOT NULL CHECK (emoji IN ('😍', '😂', '🔥', '💜', '👏')),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS creative_gallery_reactions_art_user_idx
ON public.creative_gallery_reactions (art_id, username);

CREATE INDEX IF NOT EXISTS creative_gallery_reactions_art_idx
ON public.creative_gallery_reactions (art_id);

ALTER TABLE public.creative_gallery_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Creative reactions are publicly readable" ON public.creative_gallery_reactions;
DROP POLICY IF EXISTS "Anyone can react to creative art" ON public.creative_gallery_reactions;

CREATE POLICY "Creative reactions are publicly readable"
ON public.creative_gallery_reactions
FOR SELECT
USING (true);

CREATE POLICY "Anyone can react to creative art"
ON public.creative_gallery_reactions
FOR INSERT
WITH CHECK (
    length(trim(username)) BETWEEN 1 AND 50
    AND emoji IN ('😍', '😂', '🔥', '💜', '👏')
);

CREATE POLICY "Anyone can update their creative reaction"
ON public.creative_gallery_reactions
FOR UPDATE
USING (
    length(trim(username)) BETWEEN 1 AND 50
    AND emoji IN ('😍', '😂', '🔥', '💜', '👏')
)
WITH CHECK (
    length(trim(username)) BETWEEN 1 AND 50
    AND emoji IN ('😍', '😂', '🔥', '💜', '👏')
);

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.creative_gallery_reactions TO anon, authenticated;
