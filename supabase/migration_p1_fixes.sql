-- ════════════════════════════════════════════════════════════════
--  MIGRATION P1 FIXES — POS UGT MART
--  Jalankan di Supabase → SQL Editor → Run
--  AMAN / IDEMPOTENT
-- ════════════════════════════════════════════════════════════════

-- Kolom diskon & PPN di transaksi (untuk Flutter P1-2)
ALTER TABLE transaksi
  ADD COLUMN IF NOT EXISTS diskon      integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ppn_rate    numeric(5,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ppn_nominal integer NOT NULL DEFAULT 0;

-- Kolom kasir & id_toko di kas_log (untuk Flutter saveKas)
ALTER TABLE kas_log
  ADD COLUMN IF NOT EXISTS kasir   text,
  ADD COLUMN IF NOT EXISTS id_toko bigint;

-- Kolom terbayar di transaksi (untuk piutang dari web panel)
ALTER TABLE transaksi
  ADD COLUMN IF NOT EXISTS terbayar integer;
