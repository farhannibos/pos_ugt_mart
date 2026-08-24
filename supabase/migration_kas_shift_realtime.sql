-- ════════════════════════════════════════════════════════════════════════════
--  MIGRASI — Kas Kasir Aktual (realtime, per-shift, terhubung transaksi)
--  Jalankan di Supabase → SQL Editor → Run.
--  AMAN / IDEMPOTENT — bisa dijalankan berkali-kali.
--
--  Skema yang dipakai sebagai acuan: web-panel/schema.sql (skema AKTIF).
--  JANGAN bingung dengan supabase/schema.sql — itu skema lama/tidak terpakai.
--
--  Yang dilakukan migrasi ini:
--   1. Tambah kas_log.id_shift — menghubungkan tiap mutasi kas ke sesi shift.
--   2. Cegah 2 shift 'buka' bersamaan untuk 1 toko (unique index parsial).
--   3. fn_shift_aktif()   — cari shift yang sedang 'buka' untuk sebuah toko.
--   4. Trigger di tabel `transaksi`  — penjualan Tunai/Lunas & DP piutang
--      otomatis tercatat sebagai kas masuk. Penjualan non-Tunai (QRIS/EDC/
--      Voucher/dll) TIDAK dicatat sebagai kas — ini yang memperbaiki bug
--      lama di web-panel yang mencatat SEMUA penjualan Lunas sebagai kas
--      tunai tanpa mengecek metode_bayar.
--   5. Trigger di tabel `pembelian` — pembelian berstatus Lunas otomatis
--      tercatat sebagai kas keluar.
--   6. catat_cicilan() (RPC existing, dipakai web & mobile untuk cicilan
--      piutang/hutang) di-CREATE OR REPLACE supaya juga mencatat kas
--      masuk/keluar otomatis kalau metode pembayarannya Tunai.
--   7. fn_shift_saldo() — saldo kas live sebuah shift (modal awal + kas
--      masuk - kas keluar shift itu saja), dipanggil dari web & mobile.
-- ════════════════════════════════════════════════════════════════════════════


-- ────────────────────────────────────────────────────────────────────────────
-- 1. Kolom id_shift di kas_log
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE kas_log
  ADD COLUMN IF NOT EXISTS id_shift bigint REFERENCES shift(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_kas_log_shift ON kas_log(id_shift);


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Satu toko hanya boleh punya SATU shift berstatus 'buka' pada satu waktu.
--    Model aplikasi (mobile & web) mengasumsikan single-till per toko, bukan
--    multi-kasir konkuren (getActiveShift di Flutter tidak membedakan kasir).
-- ────────────────────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS idx_shift_satu_aktif
  ON shift(id_toko) WHERE status = 'buka';


-- ────────────────────────────────────────────────────────────────────────────
-- 3. fn_shift_aktif — shift yang sedang 'buka' untuk sebuah toko.
--    Dipakai HANYA oleh trigger di bawah (dipanggil dalam konteks SECURITY
--    DEFINER trigger-nya, jadi otomatis bypass RLS, tidak perlu GRANT publik).
--
--    CATATAN PENTING (bukan bug): kalau tidak ada shift 'buka' saat baris
--    transaksi/pembelian/pembayaran ditulis (mis. entri backdated diinput
--    admin di luar jam operasional), hasilnya NULL — baris kas tetap
--    tercatat di ledger umum untuk laporan, hanya tidak menempel ke sesi
--    shift manapun. Ini benar secara logis: uang tidak bisa "masuk laci"
--    shift yang sudah ditutup.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_shift_aktif(p_id_toko bigint)
RETURNS bigint LANGUAGE sql STABLE AS $$
  SELECT id FROM shift
  WHERE id_toko = p_id_toko AND status = 'buka'
  ORDER BY jam_buka DESC LIMIT 1;
$$;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Trigger: penjualan (transaksi) → kas_log otomatis
--    Pola sama seperti fn_kurangi_stok_penjualan (migration_v2_complete.sql).
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_catat_kas_transaksi()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  IF NEW.metode_bayar = 'Tunai' AND NEW.status = 'Lunas' THEN
    INSERT INTO kas_log (id_toko, keterangan, tanggal, jam, nominal, tipe, id_kasir, id_shift)
    VALUES (NEW.id_toko, 'Penjualan ' || NEW.no_faktur, NEW.tanggal, NEW.jam,
            NEW.total, 'masuk', NEW.id_kasir, fn_shift_aktif(NEW.id_toko));

  ELSIF NEW.status = 'Piutang' AND COALESCE(NEW.terbayar, 0) > 0 THEN
    INSERT INTO kas_log (id_toko, keterangan, tanggal, jam, nominal, tipe, id_kasir, id_shift)
    VALUES (NEW.id_toko, 'DP Piutang ' || NEW.no_faktur, NEW.tanggal, NEW.jam,
            NEW.terbayar, 'masuk', NEW.id_kasir, fn_shift_aktif(NEW.id_toko));
  END IF;
  -- Metode non-Tunai (QRIS/EDC BCA/Voucher/Transfer Bank/dll) yang Lunas:
  -- sengaja TIDAK dicatat ke kas_log — bukan uang fisik di laci.
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_catat_kas_transaksi ON transaksi;
CREATE TRIGGER trg_catat_kas_transaksi
  AFTER INSERT ON transaksi FOR EACH ROW EXECUTE FUNCTION fn_catat_kas_transaksi();


-- ────────────────────────────────────────────────────────────────────────────
-- 5. Trigger: pembelian → kas_log otomatis
--    Catatan: sengaja hanya status='Lunas' (bukan juga 'Pending' seperti
--    logika lama di web-panel) — "Pending" belum tentu sudah dibayar.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_catat_kas_pembelian()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  IF NEW.status = 'Lunas' THEN
    INSERT INTO kas_log (id_toko, keterangan, tanggal, jam, nominal, tipe, id_kasir, id_shift)
    VALUES (NEW.id_toko, 'Pembelian ' || NEW.no_faktur, NEW.tanggal,
            (now() AT TIME ZONE 'Asia/Jakarta')::time,
            NEW.total, 'keluar', NEW.id_operator, fn_shift_aktif(NEW.id_toko));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_catat_kas_pembelian ON pembelian;
CREATE TRIGGER trg_catat_kas_pembelian
  AFTER INSERT ON pembelian FOR EACH ROW EXECUTE FUNCTION fn_catat_kas_pembelian();


-- ────────────────────────────────────────────────────────────────────────────
-- 6. catat_cicilan() — tambahkan pencatatan kas otomatis untuk cicilan tunai.
--    Signature TIDAK berubah, jadi GRANT EXECUTE ke anon yang sudah ada
--    (lihat migration_fix_cicilan_rpc.sql) tetap berlaku, tidak perlu re-grant.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION catat_cicilan(
  p_jenis        text,
  p_id_induk     bigint,
  p_id_toko      bigint,
  p_no_referensi text,
  p_terbayar     integer,
  p_status       text,
  p_nominal      integer,
  p_metode       text,
  p_tanggal      date
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_toko_match boolean := false;
BEGIN
  -- Validasi: pastikan id_induk memang milik p_id_toko
  IF p_jenis = 'piutang' THEN
    SELECT (id_toko = p_id_toko) INTO v_toko_match
    FROM transaksi WHERE id = p_id_induk;
  ELSE
    SELECT (id_toko = p_id_toko) INTO v_toko_match
    FROM pembelian WHERE id = p_id_induk;
  END IF;

  IF NOT COALESCE(v_toko_match, false) THEN
    RETURN false;
  END IF;

  -- INSERT riwayat pembayaran
  INSERT INTO pembayaran (jenis, no_referensi, nominal, metode, tanggal, id_toko,
                          id_transaksi, id_pembelian)
  VALUES (
    p_jenis,
    p_no_referensi,
    p_nominal,
    p_metode,
    p_tanggal,
    p_id_toko,
    CASE WHEN p_jenis = 'piutang' THEN p_id_induk ELSE NULL END,
    CASE WHEN p_jenis = 'hutang'  THEN p_id_induk ELSE NULL END
  );

  -- UPDATE terbayar & status di transaksi atau pembelian
  IF p_jenis = 'piutang' THEN
    UPDATE transaksi
    SET terbayar = p_terbayar, status = p_status
    WHERE id = p_id_induk AND id_toko = p_id_toko;
  ELSE
    UPDATE pembelian
    SET terbayar = p_terbayar, status = p_status
    WHERE id = p_id_induk AND id_toko = p_id_toko;
  END IF;

  -- Cicilan tunai → catat otomatis sebagai mutasi kas.
  -- Cicilan non-tunai (transfer, dll) tidak menyentuh kas fisik laci.
  IF p_metode = 'Tunai' THEN
    INSERT INTO kas_log (id_toko, keterangan, tanggal, jam, nominal, tipe, id_shift)
    VALUES (
      p_id_toko,
      CASE WHEN p_jenis = 'piutang'
           THEN 'Pelunasan piutang ' || p_no_referensi
           ELSE 'Pembayaran hutang ' || p_no_referensi END,
      p_tanggal,
      (now() AT TIME ZONE 'Asia/Jakarta')::time,
      p_nominal,
      CASE WHEN p_jenis = 'piutang' THEN 'masuk' ELSE 'keluar' END,
      fn_shift_aktif(p_id_toko)
    );
  END IF;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION catat_cicilan(text, bigint, bigint, text, integer, text, integer, text, date) TO anon;


-- ────────────────────────────────────────────────────────────────────────────
-- 7. fn_shift_saldo — saldo kas live sebuah shift (dipanggil dari web & mobile).
--    SECURITY DEFINER supaya tidak bergantung pada konteks RLS/auth pemanggil
--    (kas_log RLS-nya berbasis get_my_id_toko(), yang tidak selalu tersedia
--    identik di kedua klien) — cukup aman karena hanya mengembalikan 1 angka
--    agregat dari shift yang id-nya sudah diketahui pemanggil.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_shift_saldo(p_shift_id bigint)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT s.modal_awal
    + COALESCE((SELECT SUM(nominal) FROM kas_log WHERE id_shift = p_shift_id AND tipe = 'masuk'), 0)
    - COALESCE((SELECT SUM(nominal) FROM kas_log WHERE id_shift = p_shift_id AND tipe = 'keluar'), 0)
  FROM shift s WHERE s.id = p_shift_id;
$$;

GRANT EXECUTE ON FUNCTION fn_shift_saldo(bigint) TO anon;
