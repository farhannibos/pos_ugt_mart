-- ============================================================
-- SHIFT KASIR — Jalankan di Supabase > SQL Editor
-- Aman dijalankan berulang (idempotent)
-- ============================================================

-- Buat tabel jika belum ada
CREATE TABLE IF NOT EXISTS shift (
  id          bigserial    PRIMARY KEY,
  id_toko     integer      NOT NULL,
  kasir_nama  text         NOT NULL DEFAULT '',
  modal_awal  integer      NOT NULL DEFAULT 0,
  total_tunai integer      NOT NULL DEFAULT 0,
  kas_masuk   integer      NOT NULL DEFAULT 0,
  kas_keluar  integer      NOT NULL DEFAULT 0,
  saldo_akhir integer,
  selisih     integer,
  jam_buka    timestamptz  NOT NULL DEFAULT now(),
  jam_tutup   timestamptz,
  status      text         NOT NULL DEFAULT 'buka' CHECK (status IN ('buka', 'tutup')),
  catatan     text         NOT NULL DEFAULT ''
);

-- Tambah kolom yang mungkin kurang jika tabel sudah ada dengan schema lama
ALTER TABLE shift ADD COLUMN IF NOT EXISTS kasir_nama  text         NOT NULL DEFAULT '';
ALTER TABLE shift ADD COLUMN IF NOT EXISTS modal_awal  integer      NOT NULL DEFAULT 0;
ALTER TABLE shift ADD COLUMN IF NOT EXISTS total_tunai integer      NOT NULL DEFAULT 0;
ALTER TABLE shift ADD COLUMN IF NOT EXISTS kas_masuk   integer      NOT NULL DEFAULT 0;
ALTER TABLE shift ADD COLUMN IF NOT EXISTS kas_keluar  integer      NOT NULL DEFAULT 0;
ALTER TABLE shift ADD COLUMN IF NOT EXISTS saldo_akhir integer;
ALTER TABLE shift ADD COLUMN IF NOT EXISTS selisih     integer;
ALTER TABLE shift ADD COLUMN IF NOT EXISTS jam_buka    timestamptz  NOT NULL DEFAULT now();
ALTER TABLE shift ADD COLUMN IF NOT EXISTS jam_tutup   timestamptz;
ALTER TABLE shift ADD COLUMN IF NOT EXISTS catatan     text         NOT NULL DEFAULT '';

-- Pastikan status column ada dan valid
ALTER TABLE shift ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'buka';

-- Drop constraint lama jika ada, lalu buat ulang
ALTER TABLE shift DROP CONSTRAINT IF EXISTS shift_status_check;
ALTER TABLE shift ADD CONSTRAINT shift_status_check CHECK (status IN ('buka', 'tutup'));

-- RLS
ALTER TABLE shift ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_shift" ON shift;
CREATE POLICY "anon_all_shift" ON shift FOR ALL TO anon USING (true) WITH CHECK (true);
