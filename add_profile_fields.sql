-- Supabase SQL-Migration: öffentliche Profilfelder für Mitgliederseiten

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS bio text,
ADD COLUMN IF NOT EXISTS favorite_game text,
ADD COLUMN IF NOT EXISTS avatar_url text;
