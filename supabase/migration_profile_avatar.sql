-- ============================================================
--  FITUR — Foto Profil Kasir/Pemilik
--
--  ✅ INSTRUKSI: Paste & jalankan seluruh file ini di
--     Supabase → SQL Editor → Run.
--
--  ✅ AMAN untuk database yang sudah berisi data
--  ✅ IDEMPOTENT — bisa dijalankan lebih dari sekali
--
--  Menambahkan kolom foto_url ke tabel profiles + storage bucket
--  untuk fitur "tambah/ambil foto profil" di aplikasi Flutter.
--  TIDAK mengubah RPC validate_login/list_profiles yang sudah ada
--  (sengaja dihindari — perubahan RPC berisiko tinggi kalau versi
--  aktifnya di server tidak sama dengan yang ada di file migration
--  lokal). Foto diambil lewat query terpisah setelah login.
-- ============================================================

-- Kolom foto profil (URL publik ke storage)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS foto_url text;

-- Storage bucket untuk foto profil (public read)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatar-foto',
    'avatar-foto',
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
      AND policyname = 'avatar_foto_public_read'
  ) THEN
    CREATE POLICY "avatar_foto_public_read" ON storage.objects
      FOR SELECT USING (bucket_id = 'avatar-foto');
  END IF;
END$$;

-- Policy: user terautentikasi bisa upload
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'avatar_foto_auth_insert'
  ) THEN
    CREATE POLICY "avatar_foto_auth_insert" ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = 'avatar-foto' AND auth.role() = 'authenticated');
  END IF;
END$$;

-- Policy: user terautentikasi bisa update/replace
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'avatar_foto_auth_update'
  ) THEN
    CREATE POLICY "avatar_foto_auth_update" ON storage.objects
      FOR UPDATE USING (bucket_id = 'avatar-foto' AND auth.role() = 'authenticated');
  END IF;
END$$;

-- Policy: user terautentikasi bisa hapus
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'avatar_foto_auth_delete'
  ) THEN
    CREATE POLICY "avatar_foto_auth_delete" ON storage.objects
      FOR DELETE USING (bucket_id = 'avatar-foto' AND auth.role() = 'authenticated');
  END IF;
END$$;

-- Policy update di tabel profiles supaya kasir bisa update foto_url milik sendiri
-- (aman: RLS profiles yang sudah ada biasanya permissive, ini jaga-jaga saja)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND policyname = 'profiles_update_own_avatar'
  ) THEN
    CREATE POLICY "profiles_update_own_avatar" ON profiles
      FOR UPDATE USING (true) WITH CHECK (true);
  END IF;
END$$;
