alter table if exists public.users
  add column if not exists role text not null default 'member';

alter table if exists public.users
  drop constraint if exists users_role_check;

alter table if exists public.users
  add constraint users_role_check
  check (role in ('admin', 'moderator', 'vip', 'member'));

create index if not exists idx_users_role on public.users(role);
