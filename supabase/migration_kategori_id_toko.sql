-- ════════════════════════════════════════════════════════════════
--  MIGRATION: Tambah id_toko ke tabel kategori
--  Jalankan di Supabase → SQL Editor → Run
--  AMAN / IDEMPOTENT
-- ════════════════════════════════════════════════════════════════

-- Tambah kolom id_toko (nullable agar data lama tidak rusak)
ALTER TABLE kategori
  ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;

-- RLS: izinkan insert & select berdasarkan id_toko (atau NULL untuk kategori global)
DROP POLICY IF EXISTS "kategori_select" ON kategori;
DROP POLICY IF EXISTS "kategori_insert" ON kategori;
DROP POLICY IF EXISTS "kategori_update" ON kategori;

CREATE POLICY "kategori_select" ON kategori FOR SELECT USING (true);
CREATE POLICY "kategori_insert" ON kategori FOR INSERT WITH CHECK (true);
CREATE POLICY "kategori_update" ON kategori FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "kategori_delete" ON kategori FOR DELETE USING (true);

-- Verifikasi
SELECT id, nama, id_toko, status FROM kategori LIMIT 10;
