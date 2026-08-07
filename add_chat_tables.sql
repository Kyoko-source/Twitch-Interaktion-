-- Supabase SQL-Migration: Globalchat und private Nachrichten

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    channel text NOT NULL CHECK (channel IN ('global', 'private')),
    sender_username text NOT NULL REFERENCES public.users(username) ON DELETE CASCADE,
    recipient_username text REFERENCES public.users(username) ON DELETE CASCADE,
    body text NOT NULL CHECK (length(trim(body)) BETWEEN 1 AND 1200),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (channel = 'global' AND recipient_username IS NULL)
        OR
        (channel = 'private' AND recipient_username IS NOT NULL AND recipient_username <> sender_username)
    )
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Chat messages are readable" ON public.chat_messages;
DROP POLICY IF EXISTS "Chat messages can be inserted" ON public.chat_messages;

CREATE POLICY "Chat messages are readable"
ON public.chat_messages
FOR SELECT
USING (true);

CREATE POLICY "Chat messages can be inserted"
ON public.chat_messages
FOR INSERT
WITH CHECK (length(trim(body)) BETWEEN 1 AND 1200);

CREATE INDEX IF NOT EXISTS chat_messages_global_idx
ON public.chat_messages (created_at DESC)
WHERE channel = 'global';

CREATE INDEX IF NOT EXISTS chat_messages_private_pair_idx
ON public.chat_messages (sender_username, recipient_username, created_at DESC)
WHERE channel = 'private';

CREATE INDEX IF NOT EXISTS chat_messages_private_recipient_idx
ON public.chat_messages (recipient_username, sender_username, created_at DESC)
WHERE channel = 'private';

GRANT SELECT, INSERT ON public.chat_messages TO anon, authenticated;
