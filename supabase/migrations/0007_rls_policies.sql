-- Migration 7: Row Level Security
-- Aturan siapa boleh baca/tulis tabel apa, dijaga oleh DATABASE sendiri

-- Aktifkan RLS di semua tabel
alter table profiles               enable row level security;
alter table categories             enable row level security;
alter table products               enable row level security;
alter table variants               enable row level security;
alter table stock_movements        enable row level security;
alter table marketplace_connections enable row level security;
alter table marketplace_orders     enable row level security;

-- === PROFILES ===
-- Owner bisa lihat dan ubah semua profil
create policy "profiles: owner semua" on profiles
  for all using ((auth.jwt() ->> 'role') = 'owner');

-- Selain owner hanya bisa lihat data diri sendiri
create policy "profiles: lihat diri sendiri" on profiles
  for select using (auth.uid() = id);

-- === CATEGORIES ===
-- Semua role bisa semua operasi
create policy "categories: semua role" on categories
  for all using ((auth.jwt() ->> 'role') in ('owner','manager','admin'));

-- === PRODUCTS & VARIANTS ===
-- Semua role bisa lihat
create policy "products: semua bisa lihat" on products
  for select using ((auth.jwt() ->> 'role') in ('owner','manager','admin'));

-- Hanya owner yang bisa buat/ubah/hapus
create policy "products: owner kelola" on products
  for all using ((auth.jwt() ->> 'role') = 'owner');

create policy "variants: semua bisa lihat" on variants
  for select using ((auth.jwt() ->> 'role') in ('owner','manager','admin'));

create policy "variants: owner kelola" on variants
  for all using ((auth.jwt() ->> 'role') = 'owner');

-- === STOCK MOVEMENTS ===
-- Semua role bisa lihat riwayat
create policy "movements: semua bisa lihat" on stock_movements
  for select using ((auth.jwt() ->> 'role') in ('owner','manager','admin'));

-- Admin tidak boleh Manual Stock Out
create policy "movements: insert dengan batasan" on stock_movements
  for insert with check (
    (auth.jwt() ->> 'role') in ('owner','manager','admin')
    and not (
      activity = 'stock_out'
      and source = 'Manual'
      and (auth.jwt() ->> 'role') = 'admin'
    )
  );

-- === MARKETPLACE ===
create policy "marketplace_conn: semua lihat" on marketplace_connections
  for select using ((auth.jwt() ->> 'role') in ('owner','manager','admin'));

create policy "marketplace_conn: owner ubah" on marketplace_connections
  for update using ((auth.jwt() ->> 'role') = 'owner');

create policy "marketplace_orders: semua lihat" on marketplace_orders
  for select using ((auth.jwt() ->> 'role') in ('owner','manager','admin'));
