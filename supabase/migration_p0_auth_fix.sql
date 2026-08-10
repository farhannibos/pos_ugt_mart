-- ════════════════════════════════════════════════════════════════
--  AUTH FIX — validate_login + register_toko
--  Jalankan di Supabase → SQL Editor → Run
--  AMAN / IDEMPOTENT
-- ════════════════════════════════════════════════════════════════


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [1] Pastikan tabel toko ada
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS toko (
  id          bigserial    PRIMARY KEY,
  nama_toko   text         NOT NULL DEFAULT 'UGT MART',
  alamat      text,
  no_hp       text,
  plan        text         NOT NULL DEFAULT 'free'
              CHECK (plan IN ('free', 'premium')),
  expired_at  date,
  created_at  timestamptz  NOT NULL DEFAULT now()
);


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [2] Pastikan kolom password & id_toko ada di profiles
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password  text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS id_toko   bigint;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS aktif     boolean NOT NULL DEFAULT true;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [3] validate_login — drop dulu agar bisa ganti return type
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DROP FUNCTION IF EXISTS validate_login(text, text);

CREATE FUNCTION validate_login(p_username text, p_password text)
RETURNS TABLE(
  nama         text,
  role         text,
  avatar_color text,
  id_toko      bigint,
  nama_toko    text,
  plan         text,
  expired_at   date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.nama,
    p.role,
    p.avatar_color,
    p.id_toko,
    COALESCE(t.nama_toko, 'UGT MART')   AS nama_toko,
    CASE
      WHEN t.plan = 'premium'
       AND (t.expired_at IS NULL OR t.expired_at >= CURRENT_DATE)
      THEN 'premium'
      ELSE 'free'
    END                                   AS plan,
    t.expired_at
  FROM profiles p
  LEFT JOIN toko t ON t.id = p.id_toko
  WHERE lower(p.username) = lower(trim(p_username))
    AND p.password         = p_password
    AND p.aktif            = true
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION validate_login(text, text) TO anon;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [4] register_toko — buat/perbarui RPC pendaftaran toko baru
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE OR REPLACE FUNCTION register_toko(
  p_nama_toko text,
  p_alamat    text,
  p_no_hp     text,
  p_nama      text,
  p_username  text,
  p_password  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_toko_id    bigint;
  v_exists     boolean;
BEGIN
  -- Cek username sudah dipakai
  SELECT EXISTS(
    SELECT 1 FROM profiles WHERE lower(username) = lower(trim(p_username))
  ) INTO v_exists;

  IF v_exists THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Username sudah digunakan');
  END IF;

  -- Buat toko baru
  INSERT INTO toko (nama_toko, alamat, no_hp)
  VALUES (trim(p_nama_toko), trim(p_alamat), trim(p_no_hp))
  RETURNING id INTO v_toko_id;

  -- Buat profil Owner untuk toko ini
  INSERT INTO profiles (id_toko, username, password, nama, role, aktif)
  VALUES (
    v_toko_id,
    lower(trim(p_username)),
    p_password,
    trim(p_nama),
    'Owner',
    true
  );

  RETURN jsonb_build_object(
    'ok',      true,
    'id_toko', v_toko_id,
    'pesan',   'Toko berhasil didaftarkan'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION register_toko(text, text, text, text, text, text) TO anon;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [5] Cek: tampilkan user yang ada di profiles
--     (untuk verifikasi setelah migration)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SELECT id, username, nama, role, aktif, id_toko
FROM profiles
ORDER BY id;
