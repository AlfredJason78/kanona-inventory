-- Migration 6: Fungsi utama — semua perubahan stok wajib lewat sini

create or replace function record_stock_movement(
  p_variant_id     uuid,
  p_change         int,
  p_activity       movement_type,
  p_source         text,
  p_user_id        uuid,
  p_expected_stock int
) returns stock_movements as $$
declare
  v_before int;
  v_after  int;
  v_row    stock_movements;
begin
  -- Langkah 1: Kunci baris varian agar tidak ada yang mengubah bersamaan
  select current_stock into v_before
    from variants where id = p_variant_id
    for update;

  -- Langkah 2: Cek apakah stok sudah berubah sejak halaman dibuka
  if v_before <> p_expected_stock then
    raise exception 'STOCK_CHANGED:%:%', p_expected_stock, v_before;
  end if;

  -- Langkah 3: Pastikan stok tidak jadi negatif
  v_after := v_before + p_change;
  if v_after < 0 then
    raise exception 'NEGATIVE_STOCK';
  end if;

  -- Langkah 4: Tulis riwayat
  insert into stock_movements
    (variant_id, stock_before, change, stock_after, activity, source, user_id)
  values
    (p_variant_id, v_before, p_change, v_after, p_activity, p_source, p_user_id)
  returning * into v_row;

  -- Langkah 5: Update cache stok di tabel variants
  update variants
    set current_stock = v_after, updated_at = now()
    where id = p_variant_id;

  return v_row;
  -- Langkah 6: Commit otomatis saat fungsi selesai
end;
$$ language plpgsql;
