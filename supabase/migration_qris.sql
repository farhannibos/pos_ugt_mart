  -- ══════════════════════════════════════════════════════════════════════
  -- Migration: QRIS & Rekening Bank → tambah ke tabel toko + storage bucket
  -- Jalankan di: Supabase → SQL Editor
  -- Aman dijalankan berulang (idempotent)
  -- ══════════════════════════════════════════════════════════════════════

  -- [1] Tambah kolom QRIS & rekening bank ke tabel toko
  ALTER TABLE toko
    ADD COLUMN IF NOT EXISTS qris_provider    text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS qris_atas_nama   text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS qris_no_hp       text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS qris_image_url   text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS bank_nama        text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS bank_no_rekening text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS bank_atas_nama   text NOT NULL DEFAULT '';


  -- [2] Update validate_login agar ikut return kolom QRIS & rekening bank
  DROP FUNCTION IF EXISTS validate_login(text, text);
  CREATE FUNCTION validate_login(p_username text, p_password text)
  RETURNS TABLE(
    nama             text,
    role             text,
    avatar_color     text,
    id_toko          bigint,
    nama_toko        text,
    plan             text,
    expired_at       date,
    nama_pemilik     text,
    ppn_rate         numeric,
    alamat           text,
    no_hp            text,
    qris_provider    text,
    qris_atas_nama   text,
    qris_no_hp       text,
    qris_image_url   text,
    bank_nama        text,
    bank_no_rekening text,
    bank_atas_nama   text
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
      COALESCE(t.no_hp, '')                         AS no_hp,
      COALESCE(t.qris_provider, '')                 AS qris_provider,
      COALESCE(t.qris_atas_nama, '')                AS qris_atas_nama,
      COALESCE(t.qris_no_hp, '')                    AS qris_no_hp,
      COALESCE(t.qris_image_url, '')                AS qris_image_url,
      COALESCE(t.bank_nama, '')                     AS bank_nama,
      COALESCE(t.bank_no_rekening, '')               AS bank_no_rekening,
      COALESCE(t.bank_atas_nama, '')                 AS bank_atas_nama
    FROM profiles p
    LEFT JOIN toko t ON t.id = p.id_toko
    WHERE lower(p.username) = lower(trim(p_username))
      AND p.password         = p_password
      AND p.aktif            = true
    LIMIT 1;
  END;
  $$;

  GRANT EXECUTE ON FUNCTION validate_login(text, text) TO anon;


  -- [3] RPC: update_toko_qris (security definer → bypass RLS, hanya utk authenticated)
  CREATE OR REPLACE FUNCTION update_toko_qris(
    p_id_toko        bigint,
    p_qris_provider  text,
    p_qris_atas_nama text,
    p_qris_no_hp     text,
    p_qris_image_url text
  )
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
  AS $$
  BEGIN
    UPDATE toko
    SET
      qris_provider  = trim(p_qris_provider),
      qris_atas_nama = trim(p_qris_atas_nama),
      qris_no_hp     = trim(p_qris_no_hp),
      qris_image_url = trim(p_qris_image_url)
    WHERE id = p_id_toko;
  END;
  $$;

  GRANT EXECUTE ON FUNCTION update_toko_qris(bigint, text, text, text, text) TO authenticated;


  -- [4] RPC: update_toko_rekening (security definer → bypass RLS, hanya utk authenticated)
  CREATE OR REPLACE FUNCTION update_toko_rekening(
    p_id_toko          bigint,
    p_bank_nama        text,
    p_bank_no_rekening text,
    p_bank_atas_nama   text
  )
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = public
  AS $$
  BEGIN
    UPDATE toko
    SET
      bank_nama        = trim(p_bank_nama),
      bank_no_rekening = trim(p_bank_no_rekening),
      bank_atas_nama   = trim(p_bank_atas_nama)
    WHERE id = p_id_toko;
  END;
  $$;

  GRANT EXECUTE ON FUNCTION update_toko_rekening(bigint, text, text, text) TO authenticated;


  -- [5] Storage bucket untuk gambar QRIS (public, supaya getPublicUrl bisa diakses tanpa auth)
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('qris', 'qris', true)
  ON CONFLICT (id) DO NOTHING;

  DROP POLICY IF EXISTS "qris_public_select" ON storage.objects;
  DROP POLICY IF EXISTS "qris_auth_insert"   ON storage.objects;
  DROP POLICY IF EXISTS "qris_auth_update"   ON storage.objects;
  DROP POLICY IF EXISTS "qris_auth_delete"   ON storage.objects;

  CREATE POLICY "qris_public_select" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'qris');

  CREATE POLICY "qris_auth_insert" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'qris');

  CREATE POLICY "qris_auth_update" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'qris')
    WITH CHECK (bucket_id = 'qris');

  CREATE POLICY "qris_auth_delete" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'qris');
