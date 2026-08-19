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

  -- Setiap DELETE pakai to_regclass() agar aman walau migration tertentu belum dirun.

  -- [1] Hapus item-level terlebih dahulu (child dari child)
  IF to_regclass('public.transaksi_item') IS NOT NULL THEN
    DELETE FROM transaksi_item
      WHERE id_transaksi IN (SELECT id FROM transaksi WHERE id_toko = p_id_toko);
  END IF;

  IF to_regclass('public.pembelian_item') IS NOT NULL THEN
    DELETE FROM pembelian_item
      WHERE id_pembelian IN (SELECT id FROM pembelian WHERE id_toko = p_id_toko);
  END IF;

  IF to_regclass('public.stock_opname_item') IS NOT NULL THEN
    DELETE FROM stock_opname_item
      WHERE id_opname IN (SELECT id FROM stock_opname WHERE id_toko = p_id_toko);
  END IF;

  -- [2] Hapus tabel yang FK ke transaksi / pembelian
  IF to_regclass('public.pembayaran')      IS NOT NULL THEN DELETE FROM pembayaran      WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.retur_penjualan') IS NOT NULL THEN DELETE FROM retur_penjualan WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.retur_pembelian') IS NOT NULL THEN DELETE FROM retur_pembelian WHERE id_toko = p_id_toko; END IF;

  -- [3] Hapus transaksi & pembelian
  IF to_regclass('public.transaksi') IS NOT NULL THEN DELETE FROM transaksi WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.pembelian') IS NOT NULL THEN DELETE FROM pembelian WHERE id_toko = p_id_toko; END IF;

  -- [4] Hapus operasional lain
  IF to_regclass('public.kas_log')        IS NOT NULL THEN DELETE FROM kas_log        WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.shift')          IS NOT NULL THEN DELETE FROM shift          WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.shift_kasir')    IS NOT NULL THEN DELETE FROM shift_kasir    WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.stock_opname')   IS NOT NULL THEN DELETE FROM stock_opname   WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.stok_log')       IS NOT NULL THEN DELETE FROM stok_log       WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.adjustment_stok') IS NOT NULL THEN DELETE FROM adjustment_stok WHERE id_toko = p_id_toko; END IF;

  -- [5] Hapus master data toko
  IF to_regclass('public.member')   IS NOT NULL THEN DELETE FROM member   WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.produk')   IS NOT NULL THEN DELETE FROM produk   WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.kategori') IS NOT NULL THEN DELETE FROM kategori WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.supplier') IS NOT NULL THEN DELETE FROM supplier WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.cabang')   IS NOT NULL THEN DELETE FROM cabang   WHERE id_toko = p_id_toko; END IF;
  IF to_regclass('public.reseller') IS NOT NULL THEN DELETE FROM reseller WHERE id_toko = p_id_toko; END IF;

  -- [6] Hapus sesi QR dan user profiles
  IF to_regclass('public.qr_sessions') IS NOT NULL THEN
    DELETE FROM qr_sessions
      WHERE id_profile IN (SELECT id FROM profiles WHERE id_toko = p_id_toko);
  END IF;

  DELETE FROM profiles WHERE id_toko = p_id_toko;

  -- [7] Hapus langganan log
  IF to_regclass('public.langganan_log') IS NOT NULL THEN DELETE FROM langganan_log WHERE id_toko = p_id_toko; END IF;

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

