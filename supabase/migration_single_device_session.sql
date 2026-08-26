-- ════════════════════════════════════════════════════════════════════════════
--  MIGRASI — Sesi Tunggal Web Panel (1 perangkat per akun)
--  Jalankan di Supabase → SQL Editor → Run.
--  AMAN / IDEMPOTENT — bisa dijalankan berkali-kali.
--
--  Cara kerja: setiap login web berhasil menulis token acak baru ke
--  profiles.active_session_token. Browser yang login menyimpan token yang
--  sama di localStorage. Kalau akun yang sama login dari perangkat lain,
--  token di DB berubah — sesi lama (yang subscribe realtime ke baris
--  profiles miliknya) mendeteksi token sudah tidak cocok lalu logout paksa.
--  Lihat web-panel/script.js: mulaiSesiTunggal()/paksaLogoutSesiLain().
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS active_session_token text;

COMMENT ON COLUMN profiles.active_session_token IS
  'Token sesi web aktif saat ini (dipakai untuk membatasi 1 perangkat/akun). NULL = tidak ada sesi web aktif.';

-- Pastikan tabel profiles ikut di-broadcast lewat Supabase Realtime supaya
-- perubahan active_session_token bisa dideteksi instan oleh sesi lain.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
  END IF;
END$$;

-- RPC untuk menimpa token sesi. Sengaja lewat RPC (bukan UPDATE langsung dari
-- klien) supaya dibatasi ke toko sendiri (get_my_id_toko()) — kebijakan
-- UPDATE profiles yang sudah ada ("profiles_update_own_avatar") longgar untuk
-- semua baris, jadi ini jaga-jaga supaya 1 toko tidak bisa menimpa token sesi
-- toko lain.
CREATE OR REPLACE FUNCTION set_active_session(p_username text, p_token text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  UPDATE profiles
  SET active_session_token = p_token
  WHERE lower(username) = lower(trim(p_username))
    AND id_toko = get_my_id_toko();
  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION set_active_session(text, text) TO anon, authenticated;
