-- ════════════════════════════════════════════════════════════════
--  LOGIN FIX — validate_login return type patch
--  Jalankan di Supabase → SQL Editor → Run
--  AMAN / IDEMPOTENT
-- ════════════════════════════════════════════════════════════════

-- Drop dulu (wajib jika return type berubah)
DROP FUNCTION IF EXISTS validate_login(text, text);

-- Recreate dengan return type lengkap
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
