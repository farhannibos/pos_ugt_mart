-- ════════════════════════════════════════════════════════════════
--  MIGRATION: QR LOGIN — POS UGT MART
--  Tanggal : 2026-08-05
--
--  ✅ INSTRUKSI: Paste & jalankan seluruh file ini di
--     Supabase → SQL Editor → Run.
--
--  ✅ AMAN / IDEMPOTENT — bisa dijalankan lebih dari sekali.
--
--  Mengatasi masalah:
--    Fungsi QR (generate_qr_token, scan_qr_token, check_qr_status)
--    dan tabel qr_sessions belum ada di database,
--    sehingga scan QR mobile tidak terdeteksi di web panel.
-- ════════════════════════════════════════════════════════════════


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [1] Tambah kolom id_toko ke profiles (kalau belum ada)
--     Tanpa FK agar aman jika tabel toko belum dibuat.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS id_toko bigint;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [2] Tabel sesi QR
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS qr_sessions (
  id          bigserial    PRIMARY KEY,
  token       text         NOT NULL UNIQUE,
  status      text         NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending', 'scanned', 'expired')),
  id_profile  bigint       REFERENCES profiles(id) ON DELETE CASCADE,
  created_at  timestamptz  NOT NULL DEFAULT now(),
  expires_at  timestamptz  NOT NULL DEFAULT now() + interval '5 minutes'
);

CREATE INDEX IF NOT EXISTS idx_qr_token  ON qr_sessions(token);
CREATE INDEX IF NOT EXISTS idx_qr_status ON qr_sessions(status);

-- RLS: aktifkan, akses hanya via SECURITY DEFINER functions
ALTER TABLE qr_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "qr_deny_direct" ON qr_sessions;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [3] RPC: generate_qr_token
--     Dipanggil web panel saat tab QR dibuka.
--     Menggunakan gen_random_uuid() (built-in PG 13+)
--     karena pgcrypto.gen_random_bytes tidak selalu tersedia.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE OR REPLACE FUNCTION generate_qr_token()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token text;
BEGIN
  -- Bersihkan sesi lama yang sudah expired
  DELETE FROM qr_sessions WHERE expires_at < now();

  -- Buat token 64-char hex acak dari 2 UUID (tanpa tanda hubung)
  v_token := replace(gen_random_uuid()::text, '-', '')
          || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO qr_sessions (token) VALUES (v_token);

  RETURN v_token;
END;
$$;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [4] RPC: scan_qr_token
--     Dipanggil aplikasi mobile setelah scan QR.
--     Returns: {ok: bool, pesan: text}
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE OR REPLACE FUNCTION scan_qr_token(p_token text, p_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile  profiles%ROWTYPE;
  v_session  qr_sessions%ROWTYPE;
BEGIN
  -- Cek token valid: masih pending dan belum expired
  SELECT * INTO v_session
  FROM qr_sessions
  WHERE token = p_token
    AND status = 'pending'
    AND expires_at > now();

  IF NOT FOUND THEN
    PERFORM 1 FROM qr_sessions
    WHERE token = p_token AND expires_at <= now();

    IF FOUND THEN
      RETURN jsonb_build_object('ok', false, 'pesan', 'QR sudah expired');
    END IF;

    RETURN jsonb_build_object('ok', false, 'pesan', 'QR tidak valid atau sudah digunakan');
  END IF;

  -- Cari profil berdasarkan username (case-insensitive)
  SELECT * INTO v_profile
  FROM profiles
  WHERE username = lower(trim(p_username))
    AND aktif = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'User tidak ditemukan');
  END IF;

  -- Tandai QR sebagai scanned
  UPDATE qr_sessions
  SET status     = 'scanned',
      id_profile = v_profile.id
  WHERE token = p_token;

  RETURN jsonb_build_object('ok', true, 'pesan', 'QR berhasil di-scan');
END;
$$;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [5] RPC: check_qr_status
--     Dipanggil web panel tiap 2 detik (polling).
--     Returns jsonb dengan id_toko agar data toko bisa dimuat.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE OR REPLACE FUNCTION check_qr_status(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session  qr_sessions%ROWTYPE;
  v_profile  profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_session FROM qr_sessions WHERE token = p_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'expired');
  END IF;

  IF v_session.expires_at < now() OR v_session.status = 'expired' THEN
    UPDATE qr_sessions SET status = 'expired' WHERE token = p_token;
    RETURN jsonb_build_object('status', 'expired');
  END IF;

  IF v_session.status = 'pending' THEN
    RETURN jsonb_build_object('status', 'pending');
  END IF;

  -- Sudah di-scan: ambil data user
  SELECT * INTO v_profile FROM profiles WHERE id = v_session.id_profile;

  -- Hapus sesi agar tidak bisa dipakai ulang
  DELETE FROM qr_sessions WHERE token = p_token;

  -- Sertakan id_toko agar web panel bisa load data toko yang benar
  RETURN jsonb_build_object(
    'status',       'scanned',
    'nama',         v_profile.nama,
    'username',     v_profile.username,
    'role',         v_profile.role,
    'avatar_color', v_profile.avatar_color,
    'id_toko',      v_profile.id_toko
  );
END;
$$;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [6] Grant EXECUTE ke anon role
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GRANT EXECUTE ON FUNCTION generate_qr_token()          TO anon;
GRANT EXECUTE ON FUNCTION scan_qr_token(text, text)    TO anon;
GRANT EXECUTE ON FUNCTION check_qr_status(text)        TO anon;