-- Migration 4: Riwayat pergerakan stok
-- Tabel paling penting! Hanya boleh INSERT, tidak pernah UPDATE atau DELETE

create table stock_movements (
  id                   uuid primary key default gen_random_uuid(),
  variant_id           uuid not null references variants(id) on delete restrict,
  occurred_at          timestamptz not null default now(),
  stock_before         int  not null,
  change               int  not null,   -- positif = masuk, negatif = keluar
  stock_after          int  not null,
  activity             movement_type not null,
  source               text not null,   -- 'Manual' | 'Shopee' | 'Audit Stok'
  user_id              uuid references profiles(id),  -- null = dilakukan sistem
  marketplace_order_id uuid            -- diisi nanti setelah tabel marketplace dibuat
);

create index idx_movements_variant on stock_movements (variant_id, occurred_at desc);
create index idx_movements_recent  on stock_movements (occurred_at desc);
