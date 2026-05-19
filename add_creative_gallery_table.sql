-- Supabase SQL-Migration: Kreativwand und Hall of Fame

CREATE TABLE IF NOT EXISTS public.creative_gallery (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username text NOT NULL,
    title text NOT NULL DEFAULT 'Ohne Titel',
    image_data text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS creative_gallery_created_at_idx
    ON public.creative_gallery (created_at DESC);

CREATE INDEX IF NOT EXISTS creative_gallery_username_idx
    ON public.creative_gallery (username);

CREATE UNIQUE INDEX IF NOT EXISTS creative_gallery_username_unique_idx
    ON public.creative_gallery (username);
