-- ════════════════════════════════════════════════════════════════
--  MIGRASI v1.2 — Perluas CHECK constraint metode_bayar
--
--  Masalah: transaksi dengan metode 'Kartu Debit/Kredit' ditolak DB
--  karena CHECK lama hanya izinkan: Tunai, QRIS, EDC BCA, Voucher
--
--  AMAN dijalankan berulang (DROP IF EXISTS → recreate).
-- ════════════════════════════════════════════════════════════════

ALTER TABLE transaksi DROP CONSTRAINT IF EXISTS transaksi_metode_bayar_check;
ALTER TABLE transaksi DROP CONSTRAINT IF EXISTS chk_metode_bayar;

ALTER TABLE transaksi ADD CONSTRAINT chk_metode_bayar
  CHECK (metode_bayar IN (
    'Tunai',
    'QRIS',
    'EDC BCA',
    'Voucher',
    'Kartu Debit/Kredit',
    'Transfer Bank'
  ));
