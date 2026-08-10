-- ════════════════════════════════════════════════════════════════
--  MIGRASI v1.3 — Tabel pembelian_item
--
--  Tujuan: simpan detail barang per PO agar stok bisa dikembalikan
--  otomatis saat PO dihapus (fix P0-6).
--
--  AMAN dijalankan berulang (IF NOT EXISTS).
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS pembelian_item (
  id           bigserial    PRIMARY KEY,
  id_pembelian bigint       NOT NULL REFERENCES pembelian(id) ON DELETE CASCADE,
  nama_produk  text         NOT NULL,
  qty          integer      NOT NULL CHECK (qty > 0),
  harga_satuan integer      NOT NULL DEFAULT 0,
  subtotal     integer      GENERATED ALWAYS AS (qty * harga_satuan) STORED,
  created_at   timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pi_pembelian ON pembelian_item(id_pembelian);

ALTER TABLE pembelian_item ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pi_select" ON pembelian_item;
DROP POLICY IF EXISTS "pi_insert" ON pembelian_item;
DROP POLICY IF EXISTS "pi_delete" ON pembelian_item;
CREATE POLICY "pi_select" ON pembelian_item FOR SELECT USING (true);
CREATE POLICY "pi_insert" ON pembelian_item FOR INSERT WITH CHECK (true);
CREATE POLICY "pi_delete" ON pembelian_item FOR DELETE USING (true);
