-- ════════════════════════════════════════════════════════════════
--  RESET PASSWORD VIA WHATSAPP — OTP request_password_reset +
--  verify_reset_otp_and_set_password
--  Jalankan di Supabase → SQL Editor → Run
--  AMAN / IDEMPOTENT
--
--  Desain:
--  - OTP dikirim ke toko.no_hp (nomor WA pemilik toko), bukan per-akun,
--    karena profiles belum punya kolom no_hp sendiri. Cocok untuk toko
--    kecil: siapapun kasir yang lupa password, kode OTP-nya masuk ke
--    WA pemilik toko.
--  - wa_outbox = tabel log pesan keluar (placeholder pengganti gateway
--    WhatsApp asli seperti Fonnte/Wablas/WhatsApp Cloud API). Selama
--    gateway asli belum dipasang, RPC request_password_reset juga
--    mengembalikan field 'dev_otp' supaya alurnya tetap bisa dites
--    end-to-end dari aplikasi. HAPUS field dev_otp dari return value
--    (dan dari wa_outbox kalau perlu) setelah pengiriman WA asli
--    terpasang, karena saat ini OTP jadi tervisibel ke client.
-- ════════════════════════════════════════════════════════════════

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [1] Tabel OTP reset password
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS password_reset_otp (
  id             bigserial    PRIMARY KEY,
  username       text         NOT NULL,
  id_toko        bigint       NOT NULL,
  otp_code       text         NOT NULL,
  expires_at     timestamptz  NOT NULL,
  used           boolean      NOT NULL DEFAULT false,
  attempt_count  int          NOT NULL DEFAULT 0,
  created_at     timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_otp_username
  ON password_reset_otp (username, created_at DESC);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [2] Tabel log pesan WhatsApp keluar (placeholder gateway)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE TABLE IF NOT EXISTS wa_outbox (
  id          bigserial    PRIMARY KEY,
  no_hp       text         NOT NULL,
  pesan       text         NOT NULL,
  tujuan      text,                       -- mis. 'reset_password'
  status      text         NOT NULL DEFAULT 'pending', -- pending|sent|failed
  created_at  timestamptz  NOT NULL DEFAULT now()
);

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [3] request_password_reset — validasi username, generate OTP,
--     "kirim" WA (masih placeholder → dicatat ke wa_outbox)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE OR REPLACE FUNCTION request_password_reset(p_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id_toko      bigint;
  v_no_hp        text;
  v_otp          text;
  v_recent_count int;
BEGIN
  SELECT p.id_toko, t.no_hp
    INTO v_id_toko, v_no_hp
    FROM profiles p
    LEFT JOIN toko t ON t.id = p.id_toko
   WHERE lower(p.username) = lower(trim(p_username))
     AND p.aktif = true
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Username tidak ditemukan');
  END IF;

  IF v_no_hp IS NULL OR trim(v_no_hp) = '' THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Toko belum punya nomor WhatsApp terdaftar. Hubungi admin.');
  END IF;

  -- Cooldown: maksimal 1 permintaan kode per 60 detik per username
  SELECT count(*) INTO v_recent_count
    FROM password_reset_otp
   WHERE username = lower(trim(p_username))
     AND created_at > now() - interval '60 seconds';

  IF v_recent_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Tunggu sebentar sebelum meminta kode baru');
  END IF;

  v_otp := lpad(floor(random() * 1000000)::text, 6, '0');

  INSERT INTO password_reset_otp (username, id_toko, otp_code, expires_at)
  VALUES (lower(trim(p_username)), v_id_toko, v_otp, now() + interval '5 minutes');

  INSERT INTO wa_outbox (no_hp, pesan, tujuan)
  VALUES (
    v_no_hp,
    'Kode reset password UGT Mart untuk akun ' || lower(trim(p_username)) || ': ' || v_otp || ' (berlaku 5 menit, jangan bagikan ke siapapun)',
    'reset_password'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'pesan', 'Kode OTP telah dikirim ke WhatsApp toko',
    'no_hp_masked', left(v_no_hp, 4) || repeat('*', greatest(length(v_no_hp) - 7, 0)) || right(v_no_hp, 3),
    'dev_otp', v_otp -- TODO: hapus baris ini setelah gateway WhatsApp asli terpasang
  );
END;
$$;

GRANT EXECUTE ON FUNCTION request_password_reset(text) TO anon;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [4] verify_reset_otp_and_set_password — verifikasi OTP lalu
--     update password di profiles DAN Supabase Auth (email sintetis
--     username@ugtmart.internal) supaya tetap sinkron dengan
--     validateLogin() di db_service.dart
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE OR REPLACE FUNCTION verify_reset_otp_and_set_password(
  p_username     text,
  p_otp          text,
  p_new_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row RECORD;
BEGIN
  IF length(trim(p_new_password)) < 6 THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Password baru minimal 6 karakter');
  END IF;

  SELECT * INTO v_row
    FROM password_reset_otp
   WHERE username = lower(trim(p_username))
     AND used = false
   ORDER BY created_at DESC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Tidak ada permintaan reset yang aktif, minta kode baru');
  END IF;

  IF v_row.expires_at < now() THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Kode OTP sudah kedaluwarsa, minta kode baru');
  END IF;

  IF v_row.attempt_count >= 5 THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Terlalu banyak percobaan gagal, minta kode baru');
  END IF;

  IF v_row.otp_code != trim(p_otp) THEN
    UPDATE password_reset_otp SET attempt_count = attempt_count + 1 WHERE id = v_row.id;
    RETURN jsonb_build_object('ok', false, 'pesan', 'Kode OTP salah');
  END IF;

  UPDATE profiles
     SET password = p_new_password
   WHERE lower(username) = lower(trim(p_username));

  UPDATE password_reset_otp SET used = true WHERE id = v_row.id;

  -- Sinkronkan password di Supabase Auth (dipakai untuk JWT/RLS,
  -- lihat db_service.dart validateLogin()). pgcrypto sudah aktif
  -- default di Supabase.
  UPDATE auth.users
     SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
         updated_at = now()
   WHERE email = lower(trim(p_username)) || '@ugtmart.internal';

  RETURN jsonb_build_object('ok', true, 'pesan', 'Password berhasil direset');
END;
$$;

GRANT EXECUTE ON FUNCTION verify_reset_otp_and_set_password(text, text, text) TO anon;
