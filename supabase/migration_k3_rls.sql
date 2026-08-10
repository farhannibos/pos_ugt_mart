-- ════════════════════════════════════════════════════════════════
--  MIGRASI K-3 (v2): Perbaikan RLS + Fungsi Login
--  Schema aktual: web-panel/schema.sql
--  Tabel nyata: produk, transaksi, transaksi_item, profiles, dll.
--  Jalankan di Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════════

-- 1. Hapus semua policy lama (nama lama maupun nama yang mungkin sudah dibuat)
drop policy if exists allow_anon        on kategori;
drop policy if exists allow_anon        on produk;
drop policy if exists allow_anon        on barang;
drop policy if exists allow_anon        on supplier;
drop policy if exists allow_anon        on member;
drop policy if exists allow_anon        on users;
drop policy if exists allow_anon        on profiles;
drop policy if exists allow_anon        on penjualan;
drop policy if exists allow_anon        on penjualan_item;
drop policy if exists allow_anon        on transaksi;
drop policy if exists allow_anon        on transaksi_item;
drop policy if exists allow_anon        on kas_log;

drop policy if exists kategori_select   on kategori;
drop policy if exists kategori_insert   on kategori;
drop policy if exists kategori_update   on kategori;
drop policy if exists produk_select     on produk;
drop policy if exists produk_insert     on produk;
drop policy if exists produk_update     on produk;
drop policy if exists supplier_select   on supplier;
drop policy if exists supplier_insert   on supplier;
drop policy if exists supplier_update   on supplier;
drop policy if exists member_select     on member;
drop policy if exists member_insert     on member;
drop policy if exists member_update     on member;
drop policy if exists transaksi_select  on transaksi;
drop policy if exists transaksi_insert  on transaksi;
drop policy if exists transaksi_update  on transaksi;
drop policy if exists trx_item_select   on transaksi_item;
drop policy if exists trx_item_insert   on transaksi_item;
drop policy if exists kas_select        on kas_log;
drop policy if exists kas_insert        on kas_log;

-- 2. Aktifkan RLS untuk semua tabel utama
alter table if exists kategori      enable row level security;
alter table if exists produk        enable row level security;
alter table if exists supplier      enable row level security;
alter table if exists member        enable row level security;
alter table if exists transaksi     enable row level security;
alter table if exists transaksi_item enable row level security;
alter table if exists kas_log       enable row level security;
alter table if exists profiles      enable row level security;

-- 3. kategori — anon boleh baca (kasir perlu daftar kategori)
create policy "kategori_select" on kategori for select using (true);
create policy "kategori_insert" on kategori for insert with check (true);
create policy "kategori_update" on kategori for update using (true) with check (true);

-- 4. produk — anon boleh baca dan update stok (kasir POS)
create policy "produk_select" on produk for select using (true);
create policy "produk_insert" on produk for insert with check (true);
create policy "produk_update" on produk for update using (true) with check (true);

-- 5. supplier — anon boleh baca
create policy "supplier_select" on supplier for select using (true);
create policy "supplier_insert" on supplier for insert with check (true);
create policy "supplier_update" on supplier for update using (true) with check (true);

-- 6. member — anon boleh baca, tambah, update poin/total_spend
create policy "member_select" on member for select using (true);
create policy "member_insert" on member for insert with check (true);
create policy "member_update" on member for update using (true) with check (true);

-- 7. transaksi — anon boleh baca dan tambah (riwayat TIDAK boleh dihapus)
create policy "transaksi_select" on transaksi for select using (true);
create policy "transaksi_insert" on transaksi for insert with check (true);
create policy "transaksi_update" on transaksi for update using (true) with check (true);

-- 8. transaksi_item — anon boleh baca dan tambah saja (item tidak boleh diubah)
create policy "trx_item_select" on transaksi_item for select using (true);
create policy "trx_item_insert" on transaksi_item for insert with check (true);

-- 9. kas_log — anon boleh baca dan tambah
create policy "kas_select" on kas_log for select using (true);
create policy "kas_insert" on kas_log for insert with check (true);

-- 10. profiles — BLOKIR akses langsung dari anon
--     Hanya bisa diakses via validate_login (SECURITY DEFINER)
--     Tidak buat policy → semua operasi diblokir secara default

-- 11. Tambah kolom password ke profiles (untuk login tanpa Supabase Auth)
alter table profiles add column if not exists password text;

-- 12. Tambah kolom kasir (text) ke transaksi
--     Menyimpan nama kasir langsung tanpa perlu lookup FK ke profiles
alter table transaksi add column if not exists kasir text;

-- 13. Fungsi login — SECURITY DEFINER agar bisa baca profiles
--     tanpa memberi anon akses langsung ke tabel tersebut
create or replace function validate_login(p_username text, p_password text)
returns table(nama text, role text, avatar_color text)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select p.nama, p.role, p.avatar_color
  from profiles p
  where p.username = p_username
    and p.password = p_password
    and p.aktif    = true
  limit 1;
end;
$$;

grant execute on function validate_login(text, text) to anon;
