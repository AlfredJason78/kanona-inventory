-- Migration 1: Tipe data khusus (enum)
-- Enum = nilai yang sudah ditentukan, tidak bisa diisi sembarangan

create type user_role as enum ('owner', 'manager', 'admin');

create type movement_type as enum (
  'stock_in',         -- stok masuk
  'stock_out',        -- stok keluar
  'adjustment',       -- hasil audit
  'order_cancelled'   -- pesanan dibatalkan
);

create type order_status as enum (
  'pending',
  'processing',
  'shipped',
  'cancelled'
);

create type channel_name as enum (
  'shopee',
  'tokopedia',
  'tiktok_shop'
);
