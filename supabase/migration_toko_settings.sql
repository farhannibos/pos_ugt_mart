-- ══════════════════════════════════════════════════════════════════════
-- Migration: Toko Settings → tambah nama_pemilik & ppn_rate ke tabel toko
-- Jalankan di: Supabase → SQL Editor
-- ══════════════════════════════════════════════════════════════════════

-- [1] Tambah kolom ke tabel toko
ALTER TABLE toko
  ADD COLUMN IF NOT EXISTS nama_pemilik  text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS ppn_rate      numeric(5,2) NOT NULL DEFAULT 0;


-- [2] Update validate_login agar return nama_pemilik, ppn_rate, alamat, no_hp
DROP FUNCTION IF EXISTS validate_login(text, text);
CREATE FUNCTION validate_login(p_username text, p_password text)
RETURNS TABLE(
  nama         text,
  role         text,
  avatar_color text,
  id_toko      bigint,
  nama_toko    text,
  plan         text,
  expired_at   date,
  nama_pemilik text,
  ppn_rate     numeric,
  alamat       text,
  no_hp        text
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
    COALESCE(t.nama_toko, 'UGT MART')            AS nama_toko,
    CASE
      WHEN t.plan = 'premium'
       AND (t.expired_at IS NULL OR t.expired_at >= CURRENT_DATE)
      THEN 'premium'
      ELSE 'free'
    END                                            AS plan,
    t.expired_at,
    COALESCE(t.nama_pemilik, '')                  AS nama_pemilik,
    COALESCE(t.ppn_rate, 0)                       AS ppn_rate,
    COALESCE(t.alamat, '')                        AS alamat,
    COALESCE(t.no_hp, '')                         AS no_hp
  FROM profiles p
  LEFT JOIN toko t ON t.id = p.id_toko
  WHERE lower(p.username) = lower(trim(p_username))
    AND p.password         = p_password
    AND p.aktif            = true
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION validate_login(text, text) TO anon;


-- [3] Buat fungsi update_toko_settings (security definer → bypass RLS)
CREATE OR REPLACE FUNCTION update_toko_settings(
  p_id_toko      bigint,
  p_nama_toko    text,
  p_nama_pemilik text,
  p_alamat       text,
  p_no_hp        text,
  p_ppn_rate     numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE toko
  SET
    nama_toko    = trim(p_nama_toko),
    nama_pemilik = trim(p_nama_pemilik),
    alamat       = trim(p_alamat),
    no_hp        = trim(p_no_hp),
    ppn_rate     = GREATEST(0, LEAST(100, p_ppn_rate))
  WHERE id = p_id_toko;
END;
$$;

GRANT EXECUTE ON FUNCTION update_toko_settings(bigint, text, text, text, text, numeric) TO authenticated;
