create table if not exists public.aviary_pass_profiles (
    username text not null,
    season_id text not null,
    premium_unlocked boolean not null default false,
    unlocked_at timestamptz,
    created_at timestamptz not null default now(),
    primary key (username, season_id)
);

create table if not exists public.aviary_pass_claims (
    id uuid primary key default gen_random_uuid(),
    username text not null,
    season_id text not null,
    level integer not null check (level > 0),
    track text not null check (track in ('free', 'premium')),
    reward_type text not null,
    reward_value text not null,
    claimed_at timestamptz not null default now(),
    unique (username, season_id, level, track)
);

create index if not exists aviary_pass_claims_user_season_idx
    on public.aviary_pass_claims (username, season_id);

alter table public.aviary_pass_profiles enable row level security;
alter table public.aviary_pass_claims enable row level security;
