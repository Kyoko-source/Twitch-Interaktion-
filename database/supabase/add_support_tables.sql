create table if not exists public.support_messages (
    id uuid primary key default gen_random_uuid(),
    username text not null default 'Gast',
    category text not null default 'Problem',
    title text not null,
    message text not null,
    status text not null default 'open' check (status in ('open', 'done')),
    created_at timestamptz not null default now(),
    resolved_at timestamptz
);

create index if not exists support_messages_status_created_idx
    on public.support_messages (status, created_at desc);

create table if not exists public.wish_posts (
    id uuid primary key default gen_random_uuid(),
    username text not null default 'Gast',
    title text not null,
    description text not null,
    active boolean not null default true,
    created_at timestamptz not null default now()
);

create index if not exists wish_posts_active_created_idx
    on public.wish_posts (active, created_at desc);

create table if not exists public.wish_reactions (
    wish_id uuid not null references public.wish_posts(id) on delete cascade,
    username text not null,
    reaction text not null check (reaction in ('up', 'down')),
    created_at timestamptz not null default now(),
    primary key (wish_id, username)
);

create index if not exists wish_reactions_wish_idx
    on public.wish_reactions (wish_id);
