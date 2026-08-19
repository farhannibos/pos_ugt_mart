/* ════════════════════════════════════════════════════════════════════════════
   MIGRASI — Tabel shift (Shift Kasir)
   Jalankan di Supabase SQL Editor.
   ════════════════════════════════════════════════════════════════════════════ */

CREATE TABLE IF NOT EXISTS shift (
  id           bigserial    PRIMARY KEY,
  id_toko      bigint       NOT NULL REFERENCES toko(id) ON DELETE CASCADE,
  kasir_nama   text         NOT NULL DEFAULT '',
  modal_awal   integer      NOT NULL DEFAULT 0,
  status       text         NOT NULL DEFAULT 'buka'
               CHECK (status IN ('buka', 'tutup')),
  jam_buka     timestamptz  NOT NULL DEFAULT now(),
  jam_tutup    timestamptz,
  total_tunai  integer      NOT NULL DEFAULT 0,
  kas_masuk    integer      NOT NULL DEFAULT 0,
  kas_keluar   integer      NOT NULL DEFAULT 0,
  saldo_akhir  integer      NOT NULL DEFAULT 0,
  selisih      integer      NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_shift_toko_status ON shift(id_toko, status);
CREATE INDEX IF NOT EXISTS idx_shift_jam_buka    ON shift(id_toko, jam_buka);

ALTER TABLE shift ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shift_select" ON shift FOR SELECT USING (true);
CREATE POLICY "shift_insert" ON shift FOR INSERT WITH CHECK (true);
CREATE POLICY "shift_update" ON shift FOR UPDATE USING (true) WITH CHECK (true);
