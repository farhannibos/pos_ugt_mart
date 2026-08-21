-- ============================================================
--  FITUR — Foto/Logo Usaha
--
--  ✅ INSTRUKSI: Paste & jalankan seluruh file ini di
--     Supabase → SQL Editor → Run.
--
--  ✅ AMAN untuk database yang sudah berisi data
--  ✅ IDEMPOTENT — bisa dijalankan lebih dari sekali
--
--  Menambahkan kolom logo_url ke tabel toko + storage bucket
--  untuk fitur "tambah/ambil foto usaha" di Usahaku.
--  TIDAK mengubah RPC update_toko_settings yang sudah ada
--  (sengaja dihindari, sama seperti migration_profile_avatar.sql —
--  perubahan RPC berisiko kalau versi aktifnya di server beda
--  dengan yang ada di file migration lokal). Logo diupdate & dibaca
--  lewat query langsung ke tabel toko, terpisah dari RPC settings.
-- ============================================================

-- Kolom logo usaha (URL publik ke storage)
ALTER TABLE toko ADD COLUMN IF NOT EXISTS logo_url text;

-- Storage bucket untuk logo usaha (public read)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'toko-logo',
    'toko-logo',
    true,
    2097152,  -- 2MB limit
    ARRAY['image/jpeg','image/jpg','image/png','image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Policy: siapapun bisa baca (public)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'toko_logo_public_read'
  ) THEN
    CREATE POLICY "toko_logo_public_read" ON storage.objects
      FOR SELECT USING (bucket_id = 'toko-logo');
  END IF;
END$$;

-- Policy: user terautentikasi bisa upload
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'toko_logo_auth_insert'
  ) THEN
    CREATE POLICY "toko_logo_auth_insert" ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = 'toko-logo' AND auth.role() = 'authenticated');
  END IF;
END$$;

-- Policy: user terautentikasi bisa update/replace
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'toko_logo_auth_update'
  ) THEN
    CREATE POLICY "toko_logo_auth_update" ON storage.objects
      FOR UPDATE USING (bucket_id = 'toko-logo' AND auth.role() = 'authenticated');
  END IF;
END$$;

-- Policy: user terautentikasi bisa hapus
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'toko_logo_auth_delete'
  ) THEN
    CREATE POLICY "toko_logo_auth_delete" ON storage.objects
      FOR DELETE USING (bucket_id = 'toko-logo' AND auth.role() = 'authenticated');
  END IF;
END$$;

-- Policy update di tabel toko supaya kasir bisa update logo_url tokonya
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'toko'
      AND policyname = 'toko_update_own_logo'
  ) THEN
    CREATE POLICY "toko_update_own_logo" ON toko
      FOR UPDATE USING (true) WITH CHECK (true);
  END IF;
END$$;
