-- FIX: RLS policies untuk pembayaran, retur_penjualan, retur_pembelian
-- RLS aktif tapi tidak ada policy -> semua operasi diblok total
-- Jalankan di Supabase -> SQL Editor -> Run

-- PEMBAYARAN
CREATE POLICY "pembayaran_select" ON pembayaran
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "pembayaran_insert" ON pembayaran
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "pembayaran_update" ON pembayaran
  FOR UPDATE USING (id_toko = get_my_id_toko())
  WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "pembayaran_delete" ON pembayaran
  FOR DELETE USING (id_toko = get_my_id_toko());

-- RETUR PENJUALAN
CREATE POLICY "retur_jual_select" ON retur_penjualan
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "retur_jual_insert" ON retur_penjualan
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "retur_jual_update" ON retur_penjualan
  FOR UPDATE USING (id_toko = get_my_id_toko())
  WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "retur_jual_delete" ON retur_penjualan
  FOR DELETE USING (id_toko = get_my_id_toko());

-- RETUR PEMBELIAN
CREATE POLICY "retur_beli_select" ON retur_pembelian
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "retur_beli_insert" ON retur_pembelian
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "retur_beli_update" ON retur_pembelian
  FOR UPDATE USING (id_toko = get_my_id_toko())
  WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "retur_beli_delete" ON retur_pembelian
  FOR DELETE USING (id_toko = get_my_id_toko());
