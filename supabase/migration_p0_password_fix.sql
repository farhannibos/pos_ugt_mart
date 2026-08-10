-- ════════════════════════════════════════════════════════════════
--  PASSWORD FIX
--  Jalankan di Supabase → SQL Editor → Run
-- ════════════════════════════════════════════════════════════════

-- Tambah kolom password_hash jika belum ada (failsafe)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash text;

-- Sinkronkan: copy password_hash → password jika password kosong
UPDATE profiles
SET password = password_hash
WHERE password IS NULL AND password_hash IS NOT NULL;

-- Sinkronkan arah sebaliknya juga
UPDATE profiles
SET password_hash = password
WHERE password_hash IS NULL AND password IS NOT NULL;

-- Cek hasilnya
SELECT id, username, nama, role, aktif, id_toko,
       CASE WHEN password IS NOT NULL THEN 'ADA' ELSE 'KOSONG' END AS kolom_password,
       CASE WHEN password_hash IS NOT NULL THEN 'ADA' ELSE 'KOSONG' END AS kolom_password_hash
FROM profiles
ORDER BY id;
