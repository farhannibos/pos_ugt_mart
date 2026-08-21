-- ============================================================
--  FIX — metode_bayar CHECK constraint menolak 'Piutang'
--
--  ✅ INSTRUKSI: Paste & jalankan seluruh file ini di
--     Supabase → SQL Editor → Run.
--
--  ✅ AMAN untuk database yang sudah berisi data
--  ✅ IDEMPOTENT — bisa dijalankan lebih dari sekali
--
--  BUG YANG DIPERBAIKI:
--  Aplikasi Flutter mengirim metode_bayar = 'Piutang' saat kasir
--  menekan "Catat Piutang", dan metode_bayar = 'Kartu Debit/Kredit'
--  untuk pembayaran kartu. Constraint chk_metode_bayar (dibuat di
--  migration_v2_complete.sql) TIDAK mengizinkan kedua nilai ini,
--  sehingga INSERT ke tabel transaksi gagal dengan CHECK violation.
--
--  Karena app sudah menampilkan transaksi secara optimis di layar
--  (dummyHistory diisi duluan sebelum tahu hasil INSERT), kasir
--  melihat seolah transaksi berhasil — padahal tidak pernah masuk
--  ke server. Begitu data di-reload dari server, transaksi itu
--  hilang karena memang tidak pernah tersimpan.
-- ============================================================

ALTER TABLE transaksi DROP CONSTRAINT IF EXISTS chk_metode_bayar;
ALTER TABLE transaksi ADD CONSTRAINT chk_metode_bayar
  CHECK (metode_bayar IN (
    -- nilai yang dipakai app Flutter saat ini
    'Tunai', 'QRIS', 'Kartu Debit/Kredit', 'Voucher', 'Piutang',
    -- nilai lama, tetap diizinkan untuk kompatibilitas data lama / web panel
    'EDC BCA', 'Transfer Bank', 'Kartu Kredit', 'Kartu Debit', 'Non Tunai'
  ));
