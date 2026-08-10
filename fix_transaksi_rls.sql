-- ============================================================
-- FIX DATABASE UGT MART — Jalankan di Supabase > SQL Editor
-- ============================================================

-- ── FIX 1: Tambah kolom yang diinsert Flutter tapi belum ada ──
ALTER TABLE transaksi ADD COLUMN IF NOT EXISTS diskon      integer      NOT NULL DEFAULT 0;
ALTER TABLE transaksi ADD COLUMN IF NOT EXISTS ppn_rate    numeric(5,2) NOT NULL DEFAULT 0;
ALTER TABLE transaksi ADD COLUMN IF NOT EXISTS ppn_nominal integer      NOT NULL DEFAULT 0;

-- ── FIX 2: Tambah kolom kategori teks di produk (jika belum ada) ──
ALTER TABLE produk ADD COLUMN IF NOT EXISTS kategori text NOT NULL DEFAULT '';

-- ── FIX 3: Isi id_kategori dari kolom kategori teks untuk produk lama ──
UPDATE produk p
SET id_kategori = k.id
FROM kategori k
WHERE p.id_toko = k.id_toko
  AND p.kategori = k.nama
  AND p.id_kategori IS NULL
  AND p.kategori <> '';

-- ── FIX 4: Trigger kurangi stok otomatis saat transaksi_item diinsert ──
--    Flutter mengandalkan trigger ini (ada komentar di app_provider.dart)
--    tapi trigger tidak pernah dibuat — ini penyebab stok tidak berkurang di DB.
CREATE OR REPLACE FUNCTION fn_kurangi_stok_penjualan()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.id_produk IS NOT NULL THEN
    UPDATE produk
    SET stok = GREATEST(0, stok - NEW.qty)
    WHERE id = NEW.id_produk;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_kurangi_stok_penjualan ON transaksi_item;
CREATE TRIGGER trg_kurangi_stok_penjualan
AFTER INSERT ON transaksi_item
FOR EACH ROW EXECUTE FUNCTION fn_kurangi_stok_penjualan();

-- ── FIX 5: RLS — pastikan anon (Flutter & web pakai anon key) bisa INSERT & SELECT ──
ALTER TABLE transaksi     ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaksi_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE produk        ENABLE ROW LEVEL SECURITY;
ALTER TABLE kategori      ENABLE ROW LEVEL SECURITY;
ALTER TABLE member        ENABLE ROW LEVEL SECURITY;
ALTER TABLE kas_log       ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_transaksi"      ON transaksi;
DROP POLICY IF EXISTS "anon_all_transaksi_item" ON transaksi_item;
DROP POLICY IF EXISTS "anon_all_produk"         ON produk;
DROP POLICY IF EXISTS "anon_all_kategori"       ON kategori;
DROP POLICY IF EXISTS "anon_all_member"         ON member;
DROP POLICY IF EXISTS "anon_all_kas_log"        ON kas_log;

CREATE POLICY "anon_all_transaksi"      ON transaksi      FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_transaksi_item" ON transaksi_item FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_produk"         ON produk         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_kategori"       ON kategori       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_member"         ON member         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_kas_log"        ON kas_log        FOR ALL TO anon USING (true) WITH CHECK (true);
