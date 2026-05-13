-- Supabase SQL-Migration: password_hash für Gast-Login

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS password_hash text;
