-- Migration 2: Tabel profil pengguna
-- Terhubung 1:1 dengan auth.users milik Supabase

create table profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text        not null,
  role          user_role   not null,
  is_active     boolean     not null default true,
  last_login_at timestamptz,
  created_at    timestamptz not null default now()
);

-- Hanya boleh ada 1 owner selamanya
create unique index one_owner_only on profiles (role) where role = 'owner';
