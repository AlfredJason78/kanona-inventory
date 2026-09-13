-- Migration 3: Kategori, Produk, dan Varian

create table categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  created_at timestamptz not null default now()
);

create table products (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  parent_sku          text not null unique,       -- contoh: 'KMJ-OXF'
  category_id         uuid not null references categories(id),
  photo_path          text,                       -- path di Supabase Storage
  low_stock_threshold int  not null default 10,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create table variants (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references products(id) on delete restrict,
  variant_code  text not null,                    -- contoh: 'NVY-L'
  sku           text not null unique,             -- contoh: 'KMJ-OXF-NVY-L'
  color         text not null,
  size          text not null,
  price         numeric(12,2) not null,
  photo_path    text,
  current_stock int  not null default 0,          -- ini CACHE, bukan sumber kebenaran
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (product_id, variant_code)
);
