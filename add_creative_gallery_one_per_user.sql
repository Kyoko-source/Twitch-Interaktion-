-- Supabase SQL-Migration: Pro Profil nur ein Kreativwand-Bild
-- Falls ein User bereits mehrere Bilder hat, behalte das neueste und loesche die aelteren.

DELETE FROM public.creative_gallery old
USING public.creative_gallery newest
WHERE old.username = newest.username
  AND old.created_at < newest.created_at;

CREATE UNIQUE INDEX IF NOT EXISTS creative_gallery_username_unique_idx
    ON public.creative_gallery (username);
