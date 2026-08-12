-- ═══════════════════════════════════════════════════════════════
--  Migration: Bulk Satuan (jual per Kg / per Liter)
--  Jalankan di Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Ubah transaksi_item.qty: integer → numeric(10,3) ─────────
--    Diperlukan agar nilai seperti 0.5 kg / 1.75 liter bisa disimpan.
--
--    Urutan: drop constraint → drop generated subtotal → ubah tipe →
--            tambah constraint baru → tambah kolom subtotal baru.

ALTER TABLE transaksi_item DROP CONSTRAINT IF EXISTS chk_transaksi_item_qty;

-- Generated column tidak bisa di-ALTER tipe langsung, harus drop dulu
ALTER TABLE transaksi_item DROP COLUMN IF EXISTS subtotal;

ALTER TABLE transaksi_item
  ALTER COLUMN qty TYPE numeric(10,3) USING qty::numeric(10,3),
  ALTER COLUMN qty SET DEFAULT 1;

ALTER TABLE transaksi_item
  ADD CONSTRAINT chk_transaksi_item_qty CHECK (qty > 0);

-- Tambah kembali sebagai generated column; ROUND agar subtotal tetap integer
ALTER TABLE transaksi_item
  ADD COLUMN subtotal integer
  GENERATED ALWAYS AS (ROUND(harga::numeric * qty)::integer) STORED;

-- ── 2. Tambah kolom satuan ke transaksi_item ─────────────────────
--    Menyimpan satuan produk per baris item (Pcs, Kg, Liter, dll.)

ALTER TABLE transaksi_item
  ADD COLUMN IF NOT EXISTS satuan text NOT NULL DEFAULT 'Pcs';

-- ── 3. Update trigger fn_kurangi_stok_penjualan ──────────────────
--    Trigger lama: stok = stok - NEW.qty
--    Masalah: qty sekarang numeric, stok tetap integer → type mismatch.
--    Solusi: ROUND(qty) sebelum dikurangi dari stok integer.

CREATE OR REPLACE FUNCTION fn_kurangi_stok_penjualan()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_no_faktur  text;
  v_stok_lama  integer;
  v_kurangi    integer;
BEGIN
  IF NEW.id_produk IS NULL THEN RETURN NEW; END IF;

  v_kurangi := ROUND(NEW.qty)::integer;

  SELECT stok      INTO v_stok_lama FROM produk    WHERE id = NEW.id_produk;
  SELECT no_faktur INTO v_no_faktur FROM transaksi  WHERE id = NEW.id_transaksi;

  UPDATE produk
    SET stok = GREATEST(stok - v_kurangi, 0)
    WHERE id = NEW.id_produk;

  INSERT INTO stok_log (id_produk, nama_produk, stok_sebelum, stok_sesudah, tipe, referensi)
  VALUES (
    NEW.id_produk,
    NEW.nama_produk,
    v_stok_lama,
    GREATEST(v_stok_lama - v_kurangi, 0),
    'penjualan',
    v_no_faktur
  );

  RETURN NEW;
END;
$$;
