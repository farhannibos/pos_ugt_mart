-- ════════════════════════════════════════════════════════════════════════════
--  MIGRASI — Tautkan Penyesuaian Stok ke sesi Stock Opname
--  Jalankan di Supabase → SQL Editor → Run.
--  AMAN / IDEMPOTENT — bisa dijalankan berkali-kali.
--
--  Latar belakang: sebelumnya Stock Opname dan Penyesuaian Stok cuma
--  "ditautkan" di web-panel dengan menebak tanggal+petugas yang sama
--  (lihat lihatOpname/selesaikanOpname di web-panel/script.js) — rapuh:
--  salah kalau petugas yang sama bikin 2 sesi opname di hari yang sama,
--  atau bikin penyesuaian yang sebenarnya tidak terkait opname manapun.
--
--  Yang dilakukan migrasi ini:
--   1. Tambah adjustment_stok.id_opname — relasi FK nyata ke sesi opname
--      yang jadi alasan penyesuaian itu dibuat (nullable — penyesuaian
--      ad-hoc di luar sesi opname tetap boleh, id_opname-nya NULL).
--   2. Hapus stock_opname_item — tabel yang dirancang untuk menyimpan
--      rincian stok per-barang tiap sesi opname, tapi TIDAK PERNAH
--      dipakai kode aplikasi manapun (cuma ada CREATE TABLE + RLS di
--      migrasi lama, tanpa satupun insert/select terhadapnya).
-- ════════════════════════════════════════════════════════════════════════════


-- ────────────────────────────────────────────────────────────────────────────
-- 1. adjustment_stok.id_opname
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE adjustment_stok
  ADD COLUMN IF NOT EXISTS id_opname bigint REFERENCES stock_opname(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_adj_stok_opname ON adjustment_stok(id_opname);


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Hapus tabel stock_opname_item yang tidak terpakai
-- ────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS stock_opname_item;
