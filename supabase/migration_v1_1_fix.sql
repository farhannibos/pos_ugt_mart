-- ════════════════════════════════════════════════════════════════
--  MIGRASI v1.1 FIX — Jalankan di Supabase Dashboard → SQL Editor
--
--  Masalah: PO, supplier email, dan fitur cicilan tidak tersimpan
--  ke database karena kolom dan tabel berikut belum ada.
--
--  AMAN dijalankan berulang (IF NOT EXISTS / DROP IF EXISTS).
-- ════════════════════════════════════════════════════════════════

-- ── 1. Kolom cicilan & jatuh tempo untuk PEMBELIAN (HUTANG) ──────
ALTER TABLE pembelian  ADD COLUMN IF NOT EXISTS terbayar     integer NOT NULL DEFAULT 0;
ALTER TABLE pembelian  ADD COLUMN IF NOT EXISTS jatuh_tempo  date;
ALTER TABLE pembelian  ADD COLUMN IF NOT EXISTS keterangan   text;

-- ── 2. Kolom cicilan untuk TRANSAKSI (PIUTANG) ───────────────────
ALTER TABLE transaksi  ADD COLUMN IF NOT EXISTS terbayar     integer NOT NULL DEFAULT 0;
ALTER TABLE transaksi  ADD COLUMN IF NOT EXISTS jatuh_tempo  date;

-- ── 3. Kolom master yang dipakai form panel ───────────────────────
ALTER TABLE supplier   ADD COLUMN IF NOT EXISTS email        text;
ALTER TABLE member     ADD COLUMN IF NOT EXISTS email        text;
ALTER TABLE member     ADD COLUMN IF NOT EXISTS alamat       text;
ALTER TABLE cabang     ADD COLUMN IF NOT EXISTS pic          text;
ALTER TABLE reseller   ADD COLUMN IF NOT EXISTS limit_kredit integer NOT NULL DEFAULT 0;
ALTER TABLE stock_opname ADD COLUMN IF NOT EXISTS petugas    text;
ALTER TABLE stock_opname ADD COLUMN IF NOT EXISTS jumlah_item integer NOT NULL DEFAULT 0;
ALTER TABLE stock_opname ADD COLUMN IF NOT EXISTS selisih    integer NOT NULL DEFAULT 0;

-- ── 4. Kolom retur (snapshot teks supplier/pelanggan) ─────────────
ALTER TABLE retur_penjualan ADD COLUMN IF NOT EXISTS pelanggan  text;
ALTER TABLE retur_penjualan ADD COLUMN IF NOT EXISTS no_faktur  text;
ALTER TABLE retur_pembelian ADD COLUMN IF NOT EXISTS supplier   text;
ALTER TABLE retur_pembelian ADD COLUMN IF NOT EXISTS no_po      text;

-- ── 5. Tabel riwayat pembayaran cicilan ───────────────────────────
CREATE TABLE IF NOT EXISTS pembayaran (
  id            bigserial    PRIMARY KEY,
  jenis         text         NOT NULL CHECK (jenis IN ('piutang', 'hutang')),
  id_transaksi  bigint       REFERENCES transaksi(id) ON DELETE CASCADE,
  id_pembelian  bigint       REFERENCES pembelian(id) ON DELETE CASCADE,
  no_referensi  text         NOT NULL,
  nominal       integer      NOT NULL,
  metode        text         NOT NULL DEFAULT 'Tunai',
  tanggal       date         NOT NULL DEFAULT CURRENT_DATE,
  id_operator   bigint       REFERENCES profiles(id) ON DELETE SET NULL,
  created_at    timestamptz  NOT NULL DEFAULT now(),
  CHECK (nominal > 0),
  CHECK ((jenis = 'piutang' AND id_pembelian IS NULL)
      OR (jenis = 'hutang'  AND id_transaksi IS NULL))
);
CREATE INDEX IF NOT EXISTS idx_pembayaran_ref ON pembayaran(no_referensi);

-- ── 6. Tabel penyesuaian stok manual ─────────────────────────────
CREATE TABLE IF NOT EXISTS adjustment_stok (
  id           bigserial    PRIMARY KEY,
  id_produk    bigint       REFERENCES produk(id) ON DELETE SET NULL,
  nama_produk  text         NOT NULL,
  stok_sistem  integer      NOT NULL DEFAULT 0,
  stok_fisik   integer      NOT NULL DEFAULT 0,
  selisih      integer      GENERATED ALWAYS AS (stok_fisik - stok_sistem) STORED,
  keterangan   text,
  petugas      text,
  tanggal      date         NOT NULL DEFAULT CURRENT_DATE,
  created_at   timestamptz  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_adj_tanggal ON adjustment_stok(tanggal);

-- ── 7. RLS untuk tabel yang belum punya policy ────────────────────
-- pembelian
ALTER TABLE pembelian ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pembelian_select" ON pembelian;
DROP POLICY IF EXISTS "pembelian_insert" ON pembelian;
DROP POLICY IF EXISTS "pembelian_update" ON pembelian;
CREATE POLICY "pembelian_select" ON pembelian FOR SELECT USING (true);
CREATE POLICY "pembelian_insert" ON pembelian FOR INSERT WITH CHECK (true);
CREATE POLICY "pembelian_update" ON pembelian FOR UPDATE USING (true) WITH CHECK (true);

-- cabang
ALTER TABLE cabang ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cabang_select" ON cabang;
DROP POLICY IF EXISTS "cabang_insert" ON cabang;
DROP POLICY IF EXISTS "cabang_update" ON cabang;
CREATE POLICY "cabang_select" ON cabang FOR SELECT USING (true);
CREATE POLICY "cabang_insert" ON cabang FOR INSERT WITH CHECK (true);
CREATE POLICY "cabang_update" ON cabang FOR UPDATE USING (true) WITH CHECK (true);

-- reseller
ALTER TABLE reseller ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reseller_select" ON reseller;
DROP POLICY IF EXISTS "reseller_insert" ON reseller;
DROP POLICY IF EXISTS "reseller_update" ON reseller;
CREATE POLICY "reseller_select" ON reseller FOR SELECT USING (true);
CREATE POLICY "reseller_insert" ON reseller FOR INSERT WITH CHECK (true);
CREATE POLICY "reseller_update" ON reseller FOR UPDATE USING (true) WITH CHECK (true);

-- retur_penjualan
ALTER TABLE retur_penjualan ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "retur_penjualan_select" ON retur_penjualan;
DROP POLICY IF EXISTS "retur_penjualan_insert" ON retur_penjualan;
DROP POLICY IF EXISTS "retur_penjualan_update" ON retur_penjualan;
CREATE POLICY "retur_penjualan_select" ON retur_penjualan FOR SELECT USING (true);
CREATE POLICY "retur_penjualan_insert" ON retur_penjualan FOR INSERT WITH CHECK (true);
CREATE POLICY "retur_penjualan_update" ON retur_penjualan FOR UPDATE USING (true) WITH CHECK (true);

-- retur_pembelian
ALTER TABLE retur_pembelian ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "retur_pembelian_select" ON retur_pembelian;
DROP POLICY IF EXISTS "retur_pembelian_insert" ON retur_pembelian;
DROP POLICY IF EXISTS "retur_pembelian_update" ON retur_pembelian;
CREATE POLICY "retur_pembelian_select" ON retur_pembelian FOR SELECT USING (true);
CREATE POLICY "retur_pembelian_insert" ON retur_pembelian FOR INSERT WITH CHECK (true);
CREATE POLICY "retur_pembelian_update" ON retur_pembelian FOR UPDATE USING (true) WITH CHECK (true);

-- stock_opname
ALTER TABLE stock_opname ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "opname_select" ON stock_opname;
DROP POLICY IF EXISTS "opname_insert" ON stock_opname;
DROP POLICY IF EXISTS "opname_update" ON stock_opname;
CREATE POLICY "opname_select" ON stock_opname FOR SELECT USING (true);
CREATE POLICY "opname_insert" ON stock_opname FOR INSERT WITH CHECK (true);
CREATE POLICY "opname_update" ON stock_opname FOR UPDATE USING (true) WITH CHECK (true);
