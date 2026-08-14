-- ── FOTO PRODUK ───────────────────────────────────────────────────────────────
-- Tambah kolom foto_url ke tabel produk
ALTER TABLE produk ADD COLUMN IF NOT EXISTS foto_url TEXT;

-- Buat storage bucket produk-foto (public read)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'produk-foto',
    'produk-foto',
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
      AND policyname = 'produk_foto_public_read'
  ) THEN
    CREATE POLICY "produk_foto_public_read" ON storage.objects
      FOR SELECT USING (bucket_id = 'produk-foto');
  END IF;
END$$;

-- Policy: user terautentikasi bisa upload
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'produk_foto_auth_insert'
  ) THEN
    CREATE POLICY "produk_foto_auth_insert" ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = 'produk-foto' AND auth.role() = 'authenticated');
  END IF;
END$$;

-- Policy: user terautentikasi bisa update/replace
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'produk_foto_auth_update'
  ) THEN
    CREATE POLICY "produk_foto_auth_update" ON storage.objects
      FOR UPDATE USING (bucket_id = 'produk-foto' AND auth.role() = 'authenticated');
  END IF;
END$$;

-- Policy: user terautentikasi bisa hapus
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'produk_foto_auth_delete'
  ) THEN
    CREATE POLICY "produk_foto_auth_delete" ON storage.objects
      FOR DELETE USING (bucket_id = 'produk-foto' AND auth.role() = 'authenticated');
  END IF;
END$$;
