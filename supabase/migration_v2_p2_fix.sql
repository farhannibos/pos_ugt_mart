-- ════════════════════════════════════════════════════════════════
--  MIGRASI v2-P2 — POS UGT MART
--  Tanggal  : 2026-08-04
--
--  Mengatasi semua bug prioritas P2 dari audit:
--    [P2-1] updated_at tidak pernah diupdate → trigger fn_set_updated_at
--    [P2-2] member.tier dihitung di client → trigger fn_update_member_tier
--    [P2-3] Tidak ada tabel shift_kasir → buat tabel + RLS
--    [P2-4] Tidak ada tabel stok_log → buat tabel + RLS
--    [P2-5] toko_konfigurasi belum ada → buat tabel + data awal
--
--  ✅ AMAN dijalankan setelah v1.1, v1.2, v1.3 (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS)
--  ✅ IDEMPOTENT — bisa dijalankan lebih dari sekali
-- ════════════════════════════════════════════════════════════════


-- ─── [P2-1] AUTO-UPDATE updated_at ────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Pastikan kolom updated_at ada di setiap tabel (idempotent)
ALTER TABLE kategori    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE produk      ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE member      ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE supplier    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE pembelian   ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE transaksi   ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Pasang trigger (DROP + CREATE agar aman diulang)
DROP TRIGGER IF EXISTS trg_updated_at_kategori  ON kategori;
CREATE TRIGGER trg_updated_at_kategori
  BEFORE UPDATE ON kategori  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_produk ON produk;
CREATE TRIGGER trg_updated_at_produk
  BEFORE UPDATE ON produk    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_member ON member;
CREATE TRIGGER trg_updated_at_member
  BEFORE UPDATE ON member    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_supplier ON supplier;
CREATE TRIGGER trg_updated_at_supplier
  BEFORE UPDATE ON supplier  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_pembelian ON pembelian;
CREATE TRIGGER trg_updated_at_pembelian
  BEFORE UPDATE ON pembelian FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_transaksi ON transaksi;
CREATE TRIGGER trg_updated_at_transaksi
  BEFORE UPDATE ON transaksi FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


-- ─── [P2-2] MEMBER TIER OTOMATIS DI DB ────────────────────────────────
-- Tambah kolom tier jika belum ada
ALTER TABLE member ADD COLUMN IF NOT EXISTS tier text NOT NULL DEFAULT 'Reguler';

-- Fungsi trigger: hitung tier dari poin
CREATE OR REPLACE FUNCTION fn_update_member_tier()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.tier := CASE
    WHEN NEW.poin >= 1000 THEN 'Gold'
    WHEN NEW.poin >= 500  THEN 'Silver'
    ELSE 'Reguler'
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_member_tier ON member;
CREATE TRIGGER trg_member_tier
  BEFORE INSERT OR UPDATE OF poin ON member
  FOR EACH ROW EXECUTE FUNCTION fn_update_member_tier();

-- Backfill tier untuk data yang sudah ada
UPDATE member
SET tier = CASE
  WHEN poin >= 1000 THEN 'Gold'
  WHEN poin >= 500  THEN 'Silver'
  ELSE 'Reguler'
END;


-- ─── [P2-3] SHIFT KASIR ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS shift_kasir (
  id              bigserial   PRIMARY KEY,
  id_kasir        bigint      REFERENCES profiles(id) ON DELETE SET NULL,
  nama_kasir      text        NOT NULL DEFAULT '',
  tanggal         date        NOT NULL DEFAULT CURRENT_DATE,
  waktu_buka      timestamptz NOT NULL DEFAULT now(),
  waktu_tutup     timestamptz,
  kas_awal        integer     NOT NULL DEFAULT 0,
  kas_akhir       integer,
  total_penjualan integer     NOT NULL DEFAULT 0,
  catatan         text,
  status          text        NOT NULL DEFAULT 'Buka'
                  CHECK (status IN ('Buka', 'Tutup'))
);

CREATE INDEX IF NOT EXISTS idx_shift_kasir_kasir  ON shift_kasir(id_kasir, tanggal);
CREATE INDEX IF NOT EXISTS idx_shift_kasir_status ON shift_kasir(status, tanggal);

ALTER TABLE shift_kasir ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "shift_kasir_select" ON shift_kasir;
DROP POLICY IF EXISTS "shift_kasir_insert" ON shift_kasir;
DROP POLICY IF EXISTS "shift_kasir_update" ON shift_kasir;
CREATE POLICY "shift_kasir_select" ON shift_kasir FOR SELECT USING (true);
CREATE POLICY "shift_kasir_insert" ON shift_kasir FOR INSERT WITH CHECK (true);
CREATE POLICY "shift_kasir_update" ON shift_kasir FOR UPDATE USING (true) WITH CHECK (true);


-- ─── [P2-4] STOK LOG ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stok_log (
  id           bigserial   PRIMARY KEY,
  id_produk    bigint      REFERENCES produk(id) ON DELETE SET NULL,
  nama_produk  text        NOT NULL,
  stok_sebelum integer     NOT NULL,
  stok_sesudah integer     NOT NULL,
  selisih      integer     GENERATED ALWAYS AS (stok_sesudah - stok_sebelum) STORED,
  tipe         text        NOT NULL
               CHECK (tipe IN ('penjualan', 'pembelian', 'retur', 'opname', 'koreksi')),
  referensi    text,
  id_operator  bigint      REFERENCES profiles(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stok_log_produk  ON stok_log(id_produk);
CREATE INDEX IF NOT EXISTS idx_stok_log_created ON stok_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stok_log_tipe    ON stok_log(tipe);

ALTER TABLE stok_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "stok_log_select" ON stok_log;
DROP POLICY IF EXISTS "stok_log_insert" ON stok_log;
CREATE POLICY "stok_log_select" ON stok_log FOR SELECT USING (true);
CREATE POLICY "stok_log_insert" ON stok_log FOR INSERT WITH CHECK (true);


-- ─── [P2-5] TOKO KONFIGURASI ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS toko_konfigurasi (
  id         bigserial   PRIMARY KEY,
  key        text        NOT NULL UNIQUE,
  value      text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO toko_konfigurasi (key, value) VALUES
  ('nama_toko',    'UGT Mart'),
  ('alamat_toko',  ''),
  ('telepon_toko', ''),
  ('ppn_persen',   '0'),
  ('footer_struk', 'Terima kasih telah berbelanja!')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE toko_konfigurasi ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "toko_config_select" ON toko_konfigurasi;
DROP POLICY IF EXISTS "toko_config_update" ON toko_konfigurasi;
DROP POLICY IF EXISTS "toko_config_insert" ON toko_konfigurasi;
CREATE POLICY "toko_config_select" ON toko_konfigurasi FOR SELECT USING (true);
CREATE POLICY "toko_config_update" ON toko_konfigurasi FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "toko_config_insert" ON toko_konfigurasi FOR INSERT WITH CHECK (true);


-- ════════════════════════════════════════════════════════════════
-- SELESAI ✓
--   [P2-1] ✓ fn_set_updated_at → trigger di 6 tabel
--   [P2-2] ✓ fn_update_member_tier → tier otomatis, backfill data existing
--   [P2-3] ✓ shift_kasir table + RLS + index
--   [P2-4] ✓ stok_log table + RLS + index
--   [P2-5] ✓ toko_konfigurasi table + data awal + RLS
-- ════════════════════════════════════════════════════════════════
