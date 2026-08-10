-- ══════════════════════════════════════════════════════════════════════
-- Migration: Fungsi delete_toko_complete
-- Menghapus toko beserta SEMUA data terkait secara permanen
-- Jalankan di: Supabase → SQL Editor
-- ══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION delete_toko_complete(p_id_toko bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nama_toko      text;
  v_jml_transaksi  int;
  v_jml_produk     int;
  v_jml_profiles   int;
BEGIN
  -- Pastikan toko ada
  SELECT nama_toko INTO v_nama_toko FROM toko WHERE id = p_id_toko;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Toko tidak ditemukan');
  END IF;

  -- Hitung data sebelum dihapus (untuk log)
  SELECT COUNT(*) INTO v_jml_transaksi FROM transaksi   WHERE id_toko = p_id_toko;
  SELECT COUNT(*) INTO v_jml_produk    FROM produk      WHERE id_toko = p_id_toko;
  SELECT COUNT(*) INTO v_jml_profiles  FROM profiles    WHERE id_toko = p_id_toko;

  -- [1] Hapus item-level terlebih dahulu (child dari child)
  DELETE FROM transaksi_item
    WHERE id_transaksi IN (SELECT id FROM transaksi WHERE id_toko = p_id_toko);

  DELETE FROM pembelian_item
    WHERE id_pembelian IN (SELECT id FROM pembelian WHERE id_toko = p_id_toko);

  DELETE FROM stock_opname_item
    WHERE id_opname IN (SELECT id FROM stock_opname WHERE id_toko = p_id_toko);

  -- [2] Hapus tabel yang FK ke transaksi / pembelian
  DELETE FROM pembayaran       WHERE id_toko = p_id_toko;
  DELETE FROM retur_penjualan  WHERE id_toko = p_id_toko;
  DELETE FROM retur_pembelian  WHERE id_toko = p_id_toko;

  -- [3] Hapus transaksi & pembelian
  DELETE FROM transaksi    WHERE id_toko = p_id_toko;
  DELETE FROM pembelian    WHERE id_toko = p_id_toko;

  -- [4] Hapus operasional lain
  DELETE FROM kas_log        WHERE id_toko = p_id_toko;
  DELETE FROM shift          WHERE id_toko = p_id_toko;
  DELETE FROM shift_kasir    WHERE id_toko = p_id_toko;
  DELETE FROM stock_opname   WHERE id_toko = p_id_toko;
  DELETE FROM stok_log       WHERE id_toko = p_id_toko;
  DELETE FROM adjustment_stok WHERE id_toko = p_id_toko;

  -- [5] Hapus master data toko
  DELETE FROM member    WHERE id_toko = p_id_toko;
  DELETE FROM produk    WHERE id_toko = p_id_toko;
  DELETE FROM kategori  WHERE id_toko = p_id_toko;
  DELETE FROM supplier  WHERE id_toko = p_id_toko;
  DELETE FROM cabang    WHERE id_toko = p_id_toko;
  DELETE FROM reseller  WHERE id_toko = p_id_toko;

  -- [6] Hapus sesi QR dan user profiles
  DELETE FROM qr_sessions
    WHERE id_profile IN (SELECT id FROM profiles WHERE id_toko = p_id_toko);

  DELETE FROM profiles WHERE id_toko = p_id_toko;

  -- [7] Hapus langganan log
  DELETE FROM langganan_log WHERE id_toko = p_id_toko;

  -- [8] Terakhir hapus toko
  DELETE FROM toko WHERE id = p_id_toko;

  RETURN jsonb_build_object(
    'ok',          true,
    'nama_toko',   v_nama_toko,
    'transaksi',   v_jml_transaksi,
    'produk',      v_jml_produk,
    'users',       v_jml_profiles
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'pesan', SQLERRM);
END;
$$;

-- Hanya bisa dipanggil oleh role authenticated (admin web panel)
GRANT EXECUTE ON FUNCTION delete_toko_complete(bigint) TO authenticated;

