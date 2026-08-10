-- ════════════════════════════════════════════════════════════════
--  FIX: list_profiles, save_profile, deactivate_profile
--  Masalah: ketiga RPC tidak filter by id_toko → user dari toko A
--           bisa lihat/edit user dari toko B (multi-tenancy violation)
--  Jalankan di Supabase → SQL Editor → Run
-- ════════════════════════════════════════════════════════════════

-- [1] list_profiles — tambah parameter p_id_toko + WHERE filter
DROP FUNCTION IF EXISTS list_profiles();
DROP FUNCTION IF EXISTS list_profiles(bigint);

CREATE OR REPLACE FUNCTION list_profiles(p_id_toko bigint DEFAULT NULL)
RETURNS TABLE(
  id           bigint,
  username     text,
  nama         text,
  role         text,
  avatar_char  text,
  avatar_color text,
  aktif        boolean,
  created_at   timestamptz
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  SELECT id, username, nama, role, avatar_char, avatar_color, aktif, created_at
  FROM profiles
  WHERE id_toko = p_id_toko
  ORDER BY nama;
$$;

-- [2] save_profile — tambah parameter p_id_toko
--     INSERT: simpan id_toko
--     UPDATE: hanya boleh edit user milik toko sendiri
DROP FUNCTION IF EXISTS save_profile(bigint, text, text, text, text, text, boolean);
DROP FUNCTION IF EXISTS save_profile(bigint, text, text, text, text, text, boolean, bigint);

CREATE OR REPLACE FUNCTION save_profile(
  p_id          bigint   DEFAULT NULL,
  p_username    text     DEFAULT NULL,
  p_nama        text     DEFAULT NULL,
  p_role        text     DEFAULT 'Kasir',
  p_password    text     DEFAULT NULL,
  p_avatar_color text   DEFAULT '#16A34A',
  p_aktif       boolean  DEFAULT true,
  p_id_toko     bigint   DEFAULT NULL
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_id     bigint;
  v_avatar text;
BEGIN
  v_avatar := upper(left(trim(COALESCE(p_nama, '')), 1));

  IF p_id IS NULL THEN
    -- INSERT user baru, wajib ada id_toko
    INSERT INTO profiles (username, nama, role, password, avatar_char, avatar_color, aktif, id_toko)
    VALUES (
      lower(trim(p_username)),
      trim(p_nama),
      COALESCE(p_role, 'Kasir'),
      p_password,
      v_avatar,
      COALESCE(p_avatar_color, '#16A34A'),
      COALESCE(p_aktif, true),
      p_id_toko
    )
    RETURNING id INTO v_id;
  ELSE
    -- UPDATE hanya bisa kena user yang id_toko-nya sama
    UPDATE profiles SET
      username     = COALESCE(lower(trim(p_username)), username),
      nama         = COALESCE(trim(p_nama), nama),
      role         = COALESCE(p_role, role),
      password     = CASE
                       WHEN p_password IS NOT NULL AND p_password <> ''
                       THEN p_password
                       ELSE password
                     END,
      avatar_char  = v_avatar,
      avatar_color = COALESCE(p_avatar_color, avatar_color),
      aktif        = COALESCE(p_aktif, aktif)
    WHERE id = p_id
      AND id_toko = p_id_toko;
    v_id := p_id;
  END IF;

  RETURN v_id;
END;
$$;

-- [3] deactivate_profile — tambah p_id_toko agar tidak bisa
--     nonaktifkan user dari toko lain
DROP FUNCTION IF EXISTS deactivate_profile(bigint);
DROP FUNCTION IF EXISTS deactivate_profile(bigint, bigint);

CREATE OR REPLACE FUNCTION deactivate_profile(
  p_id       bigint,
  p_id_toko  bigint DEFAULT NULL
)
RETURNS void LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  UPDATE profiles
  SET aktif = false
  WHERE id = p_id
    AND id_toko = p_id_toko;
$$;

-- [4] Grant ulang
GRANT EXECUTE ON FUNCTION list_profiles(bigint)                                               TO anon;
GRANT EXECUTE ON FUNCTION save_profile(bigint, text, text, text, text, text, boolean, bigint) TO anon;
GRANT EXECUTE ON FUNCTION deactivate_profile(bigint, bigint)                                  TO anon;
