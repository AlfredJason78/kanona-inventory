-- Migration 5: Koneksi marketplace dan pesanan

create table marketplace_connections (
  id             uuid primary key default gen_random_uuid(),
  channel        channel_name not null unique,
  shop_name      text,
  is_connected   boolean not null default false,
  last_synced_at timestamptz,
  credentials    jsonb   -- API token. JANGAN pernah kirim ke browser!
);

create table marketplace_orders (
  id             uuid primary key default gen_random_uuid(),
  channel        channel_name not null,
  invoice_no     text not null,
  variant_id     uuid not null references variants(id),
  quantity       int  not null,
  status         order_status not null,
  stock_deducted boolean not null default false,  -- penjaga agar stok tidak dikurangi 2x
  ordered_at     timestamptz,
  synced_at      timestamptz not null default now(),
  unique (channel, invoice_no, variant_id)
);

-- Sekarang tambahkan foreign key yang tadi belum bisa dibuat
alter table stock_movements
  add constraint fk_marketplace_order
  foreign key (marketplace_order_id)
  references marketplace_orders(id);

-- Isi 3 baris koneksi marketplace (kosong dulu, belum terhubung)
insert into marketplace_connections (channel) values
  ('shopee'),
  ('tokopedia'),
  ('tiktok_shop');
