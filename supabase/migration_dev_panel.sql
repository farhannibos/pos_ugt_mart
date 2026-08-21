/* ════════════════════════════════════════════════════════════════════════════
   MIGRASI — WEB PANEL DEVELOPER (dev-panel)
   Jalankan blok ini di Supabase SQL Editor SETELAH migrasi v2.0 (toko,
   langganan_log, aktivasi_premium, list_toko_langganan sudah ada).
   Aman dijalankan berulang (semua statement idempotent).

   Setelah menjalankan file ini, buat login developer pertama dengan:
     select dev_create_user('admin', 'passwordAnda', 'Nama Anda');
   ════════════════════════════════════════════════════════════════════════════ */

-- ============================================================
-- 1. TABEL dev_users — akun developer/superadmin (terpisah dari profiles)
-- ============================================================
CREATE TABLE IF NOT EXISTS dev_users (
  id            bigserial    PRIMARY KEY,
  username      text         NOT NULL UNIQUE,
  password_hash text         NOT NULL,
  nama          text         NOT NULL,
  aktif         boolean      NOT NULL DEFAULT true,
  created_at    timestamptz  NOT NULL DEFAULT now()
);

ALTER TABLE dev_users ENABLE ROW LEVEL SECURITY;
-- Sengaja tidak ada policy apapun di sini -> akses tabel langsung via
-- PostgREST (anon key) ditolak total. Satu-satunya akses adalah lewat
-- fungsi SECURITY DEFINER di bawah.

CREATE OR REPLACE FUNCTION dev_create_user(
  p_username text,
  p_password text,
  p_nama     text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM dev_users WHERE username = p_username) THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Username sudah digunakan');
  END IF;

  INSERT INTO dev_users (username, password_hash, nama)
  VALUES (p_username, crypt(p_password, gen_salt('bf')), p_nama);

  RETURN jsonb_build_object('ok', true, 'pesan', 'Akun developer berhasil dibuat');
END;
$$;

CREATE OR REPLACE FUNCTION dev_validate_login(p_username text, p_password text)
RETURNS TABLE(id bigint, nama text, username text)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.nama, u.username
  FROM dev_users u
  WHERE u.username = p_username
    AND u.password_hash = crypt(p_password, u.password_hash)
    AND u.aktif = true;
END;
$$;

CREATE OR REPLACE FUNCTION dev_change_password(
  p_username     text,
  p_old_password text,
  p_new_password text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM dev_users
    WHERE username = p_username AND password_hash = crypt(p_old_password, password_hash)
  ) THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Password lama salah');
  END IF;

  UPDATE dev_users SET password_hash = crypt(p_new_password, gen_salt('bf'))
  WHERE username = p_username;

  RETURN jsonb_build_object('ok', true, 'pesan', 'Password berhasil diubah');
END;
$$;

CREATE OR REPLACE FUNCTION dev_list_users()
RETURNS TABLE(id bigint, username text, nama text, aktif boolean, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY SELECT u.id, u.username, u.nama, u.aktif, u.created_at
  FROM dev_users u ORDER BY u.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION dev_create_user(text, text, text)      TO anon;
GRANT EXECUTE ON FUNCTION dev_validate_login(text, text)          TO anon;
GRANT EXECUTE ON FUNCTION dev_change_password(text, text, text)   TO anon;
GRANT EXECUTE ON FUNCTION dev_list_users()                        TO anon;


-- ============================================================
-- 2. TABEL lisensi_request — antrian pengajuan/approval upgrade premium
-- ============================================================
CREATE TABLE IF NOT EXISTS lisensi_request (
  id               bigserial    PRIMARY KEY,
  id_toko          bigint       NOT NULL REFERENCES toko(id) ON DELETE CASCADE,
  id_device        text         NOT NULL,
  durasi_bulan     int          NOT NULL DEFAULT 1,
  harga            integer      NOT NULL DEFAULT 0,
  no_invoice       text         NOT NULL UNIQUE,
  status           text         NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'approved', 'declined')),
  catatan          text,
  diajukan_at      timestamptz  NOT NULL DEFAULT now(),
  diproses_at      timestamptz,
  diproses_oleh    text,
  id_langganan_log bigint       REFERENCES langganan_log(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_lisensi_req_toko   ON lisensi_request(id_toko);
CREATE INDEX IF NOT EXISTS idx_lisensi_req_status ON lisensi_request(status);

ALTER TABLE lisensi_request ENABLE ROW LEVEL SECURITY;
-- Tidak ada policy -> akses langsung ditolak, semua lewat RPC di bawah.

-- Generator no. invoice: INV-YYYYMMDD-0001 (reset per hari)
CREATE OR REPLACE FUNCTION _next_invoice_number()
RETURNS text
LANGUAGE plpgsql AS $$
DECLARE
  v_prefix text := 'INV-' || to_char(CURRENT_DATE, 'YYYYMMDD') || '-';
  v_count  int;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM lisensi_request
  WHERE no_invoice LIKE v_prefix || '%';

  RETURN v_prefix || lpad((v_count + 1)::text, 4, '0');
END;
$$;

-- 2a. Ajukan permintaan premium baru (dicatat manual oleh developer saat
--     toko menghubungi minta upgrade)
CREATE OR REPLACE FUNCTION dev_ajukan_lisensi(
  p_id_toko      bigint,
  p_id_device    text,
  p_durasi_bulan int     DEFAULT 1,
  p_harga        int     DEFAULT 0,
  p_catatan      text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id      bigint;
  v_invoice text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM toko WHERE id = p_id_toko) THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Toko/member tidak ditemukan');
  END IF;
  IF p_id_device IS NULL OR trim(p_id_device) = '' THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'ID Device wajib diisi');
  END IF;

  v_invoice := _next_invoice_number();

  INSERT INTO lisensi_request (id_toko, id_device, durasi_bulan, harga, no_invoice, catatan)
  VALUES (p_id_toko, trim(p_id_device), COALESCE(p_durasi_bulan, 1), COALESCE(p_harga, 0), v_invoice, p_catatan)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'no_invoice', v_invoice, 'pesan', 'Pengajuan berhasil dibuat');
END;
$$;

-- 2b. Setujui pengajuan -> aktifkan premium toko + catat ke langganan_log
CREATE OR REPLACE FUNCTION dev_approve_lisensi(
  p_id_request bigint,
  p_admin      text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_req             lisensi_request%ROWTYPE;
  v_mulai           date := CURRENT_DATE;
  v_selesai         date;
  v_current_expired date;
  v_current_plan    text;
  v_log_id          bigint;
BEGIN
  SELECT * INTO v_req FROM lisensi_request WHERE id = p_id_request;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Pengajuan tidak ditemukan');
  END IF;
  IF v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Pengajuan sudah diproses sebelumnya');
  END IF;

  SELECT plan, expired_at INTO v_current_plan, v_current_expired
  FROM toko WHERE id = v_req.id_toko;

  IF v_current_plan = 'premium' AND v_current_expired IS NOT NULL AND v_current_expired >= CURRENT_DATE THEN
    v_mulai := v_current_expired + 1;
  END IF;
  v_selesai := v_mulai + (v_req.durasi_bulan * 30) - 1;

  UPDATE toko SET plan = 'premium', expired_at = v_selesai WHERE id = v_req.id_toko;

  INSERT INTO langganan_log (id_toko, mulai, selesai, nominal, keterangan, created_by)
  VALUES (v_req.id_toko, v_mulai, v_selesai,
          v_req.harga,
          'Approve pengajuan ' || v_req.no_invoice || ' (device: ' || v_req.id_device || ')',
          p_admin)
  RETURNING id INTO v_log_id;

  UPDATE lisensi_request
  SET status = 'approved', diproses_at = now(), diproses_oleh = p_admin, id_langganan_log = v_log_id
  WHERE id = p_id_request;

  RETURN jsonb_build_object('ok', true, 'selesai', v_selesai::text,
    'pesan', 'Premium diaktifkan sampai ' || to_char(v_selesai, 'DD Mon YYYY'));
END;
$$;

-- 2c. Tolak pengajuan
CREATE OR REPLACE FUNCTION dev_decline_lisensi(
  p_id_request bigint,
  p_admin      text DEFAULT NULL,
  p_alasan     text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_status text;
BEGIN
  SELECT status INTO v_status FROM lisensi_request WHERE id = p_id_request;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Pengajuan tidak ditemukan');
  END IF;
  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Pengajuan sudah diproses sebelumnya');
  END IF;

  UPDATE lisensi_request
  SET status = 'declined', diproses_at = now(), diproses_oleh = p_admin,
      catatan = CASE WHEN p_alasan IS NULL OR trim(p_alasan) = '' THEN catatan
                      ELSE COALESCE(catatan || ' | ', '') || 'Ditolak: ' || p_alasan END
  WHERE id = p_id_request;

  RETURN jsonb_build_object('ok', true, 'pesan', 'Pengajuan ditolak');
END;
$$;

-- 2d. List pengajuan (untuk halaman User Management)
CREATE OR REPLACE FUNCTION dev_list_lisensi_requests()
RETURNS TABLE(
  id                bigint,
  no_invoice        text,
  id_device         text,
  id_toko           bigint,
  nama_toko         text,
  owner_nama        text,
  no_hp             text,
  durasi_bulan      int,
  harga             integer,
  status            text,
  catatan           text,
  diajukan_at       timestamptz,
  diproses_at       timestamptz,
  diproses_oleh     text
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id, r.no_invoice, r.id_device, r.id_toko,
    t.nama_toko, p.nama, t.no_hp,
    r.durasi_bulan, r.harga, r.status, r.catatan,
    r.diajukan_at, r.diproses_at, r.diproses_oleh
  FROM lisensi_request r
  JOIN toko t ON t.id = r.id_toko
  LEFT JOIN profiles p ON p.id_toko = t.id AND p.role = 'Owner'
  ORDER BY r.diajukan_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION dev_ajukan_lisensi(bigint, text, int, int, text) TO anon;
GRANT EXECUTE ON FUNCTION dev_approve_lisensi(bigint, text)                TO anon;
GRANT EXECUTE ON FUNCTION dev_decline_lisensi(bigint, text, text)          TO anon;
GRANT EXECUTE ON FUNCTION dev_list_lisensi_requests()                      TO anon;


-- ============================================================
-- 3. RPC DASHBOARD & LAPORAN
-- ============================================================

-- 3a. Ringkasan angka untuk kartu-kartu dashboard
CREATE OR REPLACE FUNCTION dev_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_total_aplikasi int;
  v_total_free     int;
  v_total_premium  int;
  v_hari_ini       int;
  v_pending        int;
  v_total_pengajuan int;
BEGIN
  SELECT COUNT(*) INTO v_total_aplikasi FROM toko;

  SELECT COUNT(*) INTO v_total_premium FROM toko
  WHERE plan = 'premium' AND (expired_at IS NULL OR expired_at >= CURRENT_DATE);

  v_total_free := v_total_aplikasi - v_total_premium;

  SELECT COUNT(*) INTO v_hari_ini FROM toko
  WHERE created_at::date = CURRENT_DATE;

  SELECT COUNT(*) INTO v_pending FROM lisensi_request WHERE status = 'pending';

  SELECT COUNT(*) INTO v_total_pengajuan FROM lisensi_request;

  RETURN jsonb_build_object(
    'total_aplikasi',        v_total_aplikasi,
    'total_free',             v_total_free,
    'total_premium',          v_total_premium,
    'terinstal_hari_ini',     v_hari_ini,
    'pending_requests',       v_pending,
    'total_pengajuan',        v_total_pengajuan
  );
END;
$$;

-- 3b. Data harian untuk chart "ringkasan statistik"
CREATE OR REPLACE FUNCTION dev_installs_timeseries(p_days int DEFAULT 14)
RETURNS TABLE(tanggal date, aplikasi_baru bigint, premium_aktif bigint)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  WITH hari AS (
    SELECT generate_series(CURRENT_DATE - (p_days - 1), CURRENT_DATE, interval '1 day')::date AS tanggal
  )
  SELECT
    h.tanggal,
    COALESCE((SELECT COUNT(*) FROM toko t WHERE t.created_at::date = h.tanggal), 0),
    COALESCE((SELECT COUNT(DISTINCT l.id_toko) FROM langganan_log l
              WHERE l.mulai <= h.tanggal AND l.selesai >= h.tanggal), 0)
  FROM hari h
  ORDER BY h.tanggal;
END;
$$;

-- 3c. Aktivitas terbaru (gabungan toko baru + pengajuan lisensi)
CREATE OR REPLACE FUNCTION dev_recent_activity(p_limit int DEFAULT 15)
RETURNS TABLE(jenis text, judul text, keterangan text, waktu timestamptz)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  (
    SELECT 'toko_baru'::text, t.nama_toko, 'Aplikasi baru terinstal', t.created_at
    FROM toko t
    ORDER BY t.created_at DESC
    LIMIT p_limit
  )
  UNION ALL
  (
    SELECT
      'lisensi_' || r.status,
      t.nama_toko,
      CASE r.status
        WHEN 'pending'  THEN 'Mengajukan premium (' || r.no_invoice || ')'
        WHEN 'approved' THEN 'Premium disetujui (' || r.no_invoice || ')'
        ELSE 'Pengajuan ditolak (' || r.no_invoice || ')'
      END,
      COALESCE(r.diproses_at, r.diajukan_at)
    FROM lisensi_request r
    JOIN toko t ON t.id = r.id_toko
    ORDER BY COALESCE(r.diproses_at, r.diajukan_at) DESC
    LIMIT p_limit
  )
  ORDER BY waktu DESC
  LIMIT p_limit;
END;
$$;

-- 3d. Laporan pendapatan (menu Laporan)
CREATE OR REPLACE FUNCTION dev_laporan_pendapatan(p_start date, p_end date)
RETURNS TABLE(
  id_toko    bigint,
  nama_toko  text,
  mulai      date,
  selesai    date,
  nominal    integer,
  keterangan text,
  created_by text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT l.id_toko, t.nama_toko, l.mulai, l.selesai, l.nominal, l.keterangan, l.created_by, l.created_at
  FROM langganan_log l
  JOIN toko t ON t.id = l.id_toko
  WHERE l.created_at::date BETWEEN p_start AND p_end
  ORDER BY l.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION dev_dashboard_stats()             TO anon;
GRANT EXECUTE ON FUNCTION dev_installs_timeseries(int)       TO anon;
GRANT EXECUTE ON FUNCTION dev_recent_activity(int)           TO anon;
GRANT EXECUTE ON FUNCTION dev_laporan_pendapatan(date, date) TO anon;
