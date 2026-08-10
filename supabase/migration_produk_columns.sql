-- ════════════════════════════════════════════════════════════════
--  MIGRATION: Tambah kolom yang dibutuhkan mobile app di tabel produk
--  Jalankan di Supabase → SQL Editor → Run
--  AMAN / IDEMPOTENT
-- ════════════════════════════════════════════════════════════════

-- Tambah kolom yang mungkin belum ada di tabel produk
ALTER TABLE produk
  ADD COLUMN IF NOT EXISTS kategori     text        NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS harga_beli   integer     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS harga_jual   integer     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stok_minimum integer     NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS barcode      text        NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS status       text        NOT NULL DEFAULT 'Aktif'
    CHECK (status IN ('Aktif', 'Non-aktif'));

-- Pastikan RLS produk mengizinkan INSERT dan UPDATE dari mobile
DROP POLICY IF EXISTS "produk_insert" ON produk;
DROP POLICY IF EXISTS "produk_update" ON produk;
DROP POLICY IF EXISTS "produk_delete" ON produk;

CREATE POLICY "produk_insert" ON produk FOR INSERT WITH CHECK (true);
CREATE POLICY "produk_update" ON produk FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "produk_delete" ON produk FOR DELETE USING (true);

-- Verifikasi kolom yang ada
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'produk'
ORDER BY ordinal_position;
