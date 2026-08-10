-- ════════════════════════════════════════════════════════════════
--  FIX: Tambah DELETE policy untuk semua tabel
--  Masalah: migration_supabase_auth.sql tidak membuat DELETE policy
--           → semua operasi DELETE diblok RLS
--  Jalankan di Supabase → SQL Editor → Run
-- ════════════════════════════════════════════════════════════════

CREATE POLICY "produk_delete" ON produk
  FOR DELETE USING (id_toko = get_my_id_toko());

CREATE POLICY "member_delete" ON member
  FOR DELETE USING (id_toko = get_my_id_toko());

CREATE POLICY "kategori_delete" ON kategori
  FOR DELETE USING (id_toko = get_my_id_toko());

CREATE POLICY "supplier_delete" ON supplier
  FOR DELETE USING (id_toko = get_my_id_toko());

CREATE POLICY "transaksi_delete" ON transaksi
  FOR DELETE USING (id_toko = get_my_id_toko());

CREATE POLICY "trx_item_delete" ON transaksi_item
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM transaksi t
      WHERE t.id = transaksi_item.id_transaksi
        AND t.id_toko = get_my_id_toko()
    )
  );

CREATE POLICY "kas_delete" ON kas_log
  FOR DELETE USING (id_toko = get_my_id_toko());

CREATE POLICY "pembelian_delete" ON pembelian
  FOR DELETE USING (id_toko = get_my_id_toko());
