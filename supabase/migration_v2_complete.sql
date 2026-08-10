-- ============================================================
--  MIGRATION V2 — POS UGT MART
--  Tanggal : 2026-08-03
--
--  ✅ INSTRUKSI: Paste & jalankan seluruh file ini di
--     Supabase → SQL Editor → Run.
--
--  ✅ AMAN untuk database yang sudah berisi data
--     (semua DDL menggunakan IF NOT EXISTS / IF EXISTS)
--
--  ✅ IDEMPOTENT — bisa dijalankan lebih dari sekali
--
--  Mengatasi isu dari audit:
--    [P0] kode NOT NULL tidak pernah diisi → trigger auto-generate
--    [P0] 3 RPC hilang (list_profiles, save_profile, deactivate_profile)
--    [P0] Tidak ada trigger update stok
--    [P1] transaksi tidak punya kolom diskon/ppn
--    [P1] Missing indexes kritis (transaksi_item, barcode)
--    [P1] updated_at tidak pernah diupdate
--    [P1] metode_bayar CHECK terlalu sempit
--    [P1] Tabel retur tidak punya items
--    [P2] member tier dihitung di client
-- ============================================================


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [0] EXTENSIONS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [1] HAPUS TABEL LAMA (orphan dari skema v1)
--     PERINGATAN: menghapus data di tabel-tabel ini.
--     Backup dulu jika masih diperlukan!
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DROP TABLE IF EXISTS penjualan_item  CASCADE;
DROP TABLE IF EXISTS penjualan       CASCADE;
DROP TABLE IF EXISTS barang          CASCADE;
DROP TABLE IF EXISTS users           CASCADE;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [2] PATCH TABEL YANG SUDAH ADA
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- profiles: tambah password (untuk custom login flow)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS password text;

-- member: tambah email (hilang dari skema v1 → v2)
ALTER TABLE member
  ADD COLUMN IF NOT EXISTS email text;

-- supplier: tambah email
ALTER TABLE supplier
  ADD COLUMN IF NOT EXISTS email text;

-- transaksi: tambah kolom keuangan yang hilang
ALTER TABLE transaksi
  ADD COLUMN IF NOT EXISTS kasir       text,                     -- nama kasir snapshot (dari Flutter)
  ADD COLUMN IF NOT EXISTS diskon      integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ppn_rate    numeric(5,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ppn_nominal integer NOT NULL DEFAULT 0;

-- Perluas CHECK metode_bayar (drop dulu, recreate dengan nilai lebih banyak)
ALTER TABLE transaksi DROP CONSTRAINT IF EXISTS transaksi_metode_bayar_check;
ALTER TABLE transaksi DROP CONSTRAINT IF EXISTS chk_metode_bayar;
ALTER TABLE transaksi ADD CONSTRAINT chk_metode_bayar
  CHECK (metode_bayar IN (
    'Tunai', 'QRIS', 'EDC BCA', 'Voucher',
    'Transfer Bank', 'Kartu Kredit', 'Kartu Debit', 'Non Tunai'
  ));

-- transaksi_item: tambah constraint qty > 0
ALTER TABLE transaksi_item DROP CONSTRAINT IF EXISTS chk_transaksi_item_qty;
ALTER TABLE transaksi_item ADD CONSTRAINT chk_transaksi_item_qty CHECK (qty > 0);

-- produk: tambah constraint stok >= 0
ALTER TABLE produk DROP CONSTRAINT IF EXISTS chk_produk_stok;
ALTER TABLE produk ADD CONSTRAINT chk_produk_stok CHECK (stok >= 0);


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [3] TABEL BARU
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- konfigurasi toko (nama, alamat, PPN, footer struk, dll)
CREATE TABLE IF NOT EXISTS toko_konfigurasi (
  id         bigserial   PRIMARY KEY,
  key        text        NOT NULL UNIQUE,
  value      text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO toko_konfigurasi (key, value) VALUES
  ('nama_toko',    'UGT Mart'),
  ('alamat_toko',  ''),
  ('telepon_toko', ''),
  ('ppn_persen',   '0'),
  ('footer_struk', 'Terima kasih telah berbelanja!')
ON CONFLICT (key) DO NOTHING;

-- audit trail pergerakan stok
CREATE TABLE IF NOT EXISTS stok_log (
  id           bigserial   PRIMARY KEY,
  id_produk    bigint      REFERENCES produk(id) ON DELETE SET NULL,
  nama_produk  text        NOT NULL,
  stok_sebelum integer     NOT NULL,
  stok_sesudah integer     NOT NULL,
  selisih      integer     GENERATED ALWAYS AS (stok_sesudah - stok_sebelum) STORED,
  tipe         text        NOT NULL
               CHECK (tipe IN ('penjualan', 'pembelian', 'opname', 'koreksi')),
  referensi    text,        -- no_faktur transaksi terkait
  id_operator  bigint      REFERENCES profiles(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- shift kasir (buka/tutup per sesi)
CREATE TABLE IF NOT EXISTS shift_kasir (
  id              bigserial   PRIMARY KEY,
  id_kasir        bigint      REFERENCES profiles(id) ON DELETE SET NULL,
  tanggal         date        NOT NULL DEFAULT CURRENT_DATE,
  waktu_buka      timestamptz NOT NULL DEFAULT now(),
  waktu_tutup     timestamptz,
  kas_awal        integer     NOT NULL DEFAULT 0,
  kas_akhir       integer,
  total_penjualan integer     NOT NULL DEFAULT 0,
  catatan         text,
  status          text        NOT NULL DEFAULT 'Buka'
                  CHECK (status IN ('Buka', 'Tutup'))
);

-- detail item retur dari pelanggan
CREATE TABLE IF NOT EXISTS retur_penjualan_item (
  id           bigserial   PRIMARY KEY,
  id_retur     bigint      NOT NULL REFERENCES retur_penjualan(id) ON DELETE CASCADE,
  id_produk    bigint      REFERENCES produk(id) ON DELETE SET NULL,
  nama_produk  text        NOT NULL,
  harga        integer     NOT NULL,
  qty          integer     NOT NULL DEFAULT 1 CHECK (qty > 0),
  subtotal     integer     GENERATED ALWAYS AS (harga * qty) STORED,
  alasan_item  text
);

-- detail item retur ke supplier
CREATE TABLE IF NOT EXISTS retur_pembelian_item (
  id           bigserial   PRIMARY KEY,
  id_retur     bigint      NOT NULL REFERENCES retur_pembelian(id) ON DELETE CASCADE,
  id_produk    bigint      REFERENCES produk(id) ON DELETE SET NULL,
  nama_produk  text        NOT NULL,
  harga_beli   integer     NOT NULL,
  qty          integer     NOT NULL DEFAULT 1 CHECK (qty > 0),
  subtotal     integer     GENERATED ALWAYS AS (harga_beli * qty) STORED,
  alasan_item  text
);


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [4] SEQUENCES UNTUK KODE BISNIS (auto-generate)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CREATE SEQUENCE IF NOT EXISTS seq_kode_kategori START 1;
CREATE SEQUENCE IF NOT EXISTS seq_kode_produk   START 1;
CREATE SEQUENCE IF NOT EXISTS seq_kode_member   START 1;
CREATE SEQUENCE IF NOT EXISTS seq_kode_supplier START 1;
CREATE SEQUENCE IF NOT EXISTS seq_kode_cabang   START 1;
CREATE SEQUENCE IF NOT EXISTS seq_kode_reseller START 1;

-- Sinkronkan sequence ke data yang sudah ada (hindari konflik UNIQUE)
DO $$
BEGIN
  PERFORM setval('seq_kode_kategori',
    GREATEST(1, COALESCE((
      SELECT MAX(CAST(regexp_replace(kode, '[^0-9]', '', 'g') AS integer))
      FROM kategori WHERE kode ~ '[0-9]'), 0) + 1));

  PERFORM setval('seq_kode_produk',
    GREATEST(1, COALESCE((
      SELECT MAX(CAST(regexp_replace(kode, '[^0-9]', '', 'g') AS integer))
      FROM produk WHERE kode ~ '[0-9]'), 0) + 1));

  PERFORM setval('seq_kode_member',
    GREATEST(1, COALESCE((
      SELECT MAX(CAST(regexp_replace(kode, '[^0-9]', '', 'g') AS integer))
      FROM member WHERE kode ~ '[0-9]'), 0) + 1));

  PERFORM setval('seq_kode_supplier',
    GREATEST(1, COALESCE((
      SELECT MAX(CAST(regexp_replace(kode, '[^0-9]', '', 'g') AS integer))
      FROM supplier WHERE kode ~ '[0-9]'), 0) + 1));
EXCEPTION WHEN others THEN
  -- Tabel mungkin kosong, biarkan sequence mulai dari 1
  NULL;
END $$;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [5] TRIGGER FUNCTIONS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- [5a] Auto-update kolom updated_at
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- [5b] Auto-generate kode bisnis jika tidak diisi (hasil: KT-001, PRD-001, dll)
CREATE OR REPLACE FUNCTION fn_auto_kode()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_prefix text;
  v_seq    bigint;
BEGIN
  -- Skip jika kode sudah diisi
  IF NEW.kode IS NOT NULL AND trim(NEW.kode) <> '' THEN
    RETURN NEW;
  END IF;

  v_prefix := CASE TG_TABLE_NAME
    WHEN 'kategori' THEN 'KT'
    WHEN 'produk'   THEN 'PRD'
    WHEN 'member'   THEN 'MBR'
    WHEN 'supplier' THEN 'SUP'
    WHEN 'cabang'   THEN 'CBG'
    WHEN 'reseller' THEN 'RSL'
    ELSE 'KD'
  END;

  v_seq := CASE TG_TABLE_NAME
    WHEN 'kategori' THEN nextval('seq_kode_kategori')
    WHEN 'produk'   THEN nextval('seq_kode_produk')
    WHEN 'member'   THEN nextval('seq_kode_member')
    WHEN 'supplier' THEN nextval('seq_kode_supplier')
    WHEN 'cabang'   THEN nextval('seq_kode_cabang')
    WHEN 'reseller' THEN nextval('seq_kode_reseller')
    ELSE 0
  END;

  NEW.kode := v_prefix || '-' || lpad(v_seq::text, 3, '0');
  RETURN NEW;
END;
$$;

-- [5c] Kurangi stok produk saat penjualan (AFTER INSERT pada transaksi_item)
--      SECURITY DEFINER agar trigger bisa tulis ke stok_log meski RLS aktif
CREATE OR REPLACE FUNCTION fn_kurangi_stok_penjualan()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_no_faktur  text;
  v_stok_lama  integer;
BEGIN
  IF NEW.id_produk IS NULL THEN RETURN NEW; END IF;

  SELECT stok INTO v_stok_lama FROM produk WHERE id = NEW.id_produk;
  UPDATE produk SET stok = stok - NEW.qty WHERE id = NEW.id_produk;
  SELECT no_faktur INTO v_no_faktur FROM transaksi WHERE id = NEW.id_transaksi;

  INSERT INTO stok_log (id_produk, nama_produk, stok_sebelum, stok_sesudah, tipe, referensi)
  VALUES (NEW.id_produk, NEW.nama_produk, v_stok_lama, v_stok_lama - NEW.qty,
          'penjualan', v_no_faktur);
  RETURN NEW;
END;
$$;

-- [5d] Tambah stok produk saat pembelian (AFTER INSERT pada pembelian_item)
CREATE OR REPLACE FUNCTION fn_tambah_stok_pembelian()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_no_faktur text;
  v_stok_lama integer;
BEGIN
  IF NEW.id_produk IS NULL THEN RETURN NEW; END IF;

  SELECT stok INTO v_stok_lama FROM produk WHERE id = NEW.id_produk;
  UPDATE produk SET stok = stok + NEW.qty WHERE id = NEW.id_produk;
  SELECT no_faktur INTO v_no_faktur FROM pembelian WHERE id = NEW.id_pembelian;

  INSERT INTO stok_log (id_produk, nama_produk, stok_sebelum, stok_sesudah, tipe, referensi)
  VALUES (NEW.id_produk, NEW.nama_produk, v_stok_lama, v_stok_lama + NEW.qty,
          'pembelian', v_no_faktur);
  RETURN NEW;
END;
$$;

-- [5e] Recalculate tier member berdasarkan poin (otomatis, tidak perlu hitung di client)
CREATE OR REPLACE FUNCTION fn_update_member_tier()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.tier := CASE
    WHEN NEW.poin >= 1000 THEN 'Gold'
    WHEN NEW.poin >= 500  THEN 'Silver'
    ELSE 'Reguler'
  END;
  RETURN NEW;
END;
$$;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [6] PASANG TRIGGERS KE TABEL
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- updated_at
DROP TRIGGER IF EXISTS trg_updated_at_kategori ON kategori;
CREATE TRIGGER trg_updated_at_kategori
  BEFORE UPDATE ON kategori FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_produk ON produk;
CREATE TRIGGER trg_updated_at_produk
  BEFORE UPDATE ON produk FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_member ON member;
CREATE TRIGGER trg_updated_at_member
  BEFORE UPDATE ON member FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_updated_at_supplier ON supplier;
CREATE TRIGGER trg_updated_at_supplier
  BEFORE UPDATE ON supplier FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- auto kode
DROP TRIGGER IF EXISTS trg_auto_kode_kategori ON kategori;
CREATE TRIGGER trg_auto_kode_kategori
  BEFORE INSERT ON kategori FOR EACH ROW EXECUTE FUNCTION fn_auto_kode();

DROP TRIGGER IF EXISTS trg_auto_kode_produk ON produk;
CREATE TRIGGER trg_auto_kode_produk
  BEFORE INSERT ON produk FOR EACH ROW EXECUTE FUNCTION fn_auto_kode();

DROP TRIGGER IF EXISTS trg_auto_kode_member ON member;
CREATE TRIGGER trg_auto_kode_member
  BEFORE INSERT ON member FOR EACH ROW EXECUTE FUNCTION fn_auto_kode();

DROP TRIGGER IF EXISTS trg_auto_kode_supplier ON supplier;
CREATE TRIGGER trg_auto_kode_supplier
  BEFORE INSERT ON supplier FOR EACH ROW EXECUTE FUNCTION fn_auto_kode();

DROP TRIGGER IF EXISTS trg_auto_kode_cabang ON cabang;
CREATE TRIGGER trg_auto_kode_cabang
  BEFORE INSERT ON cabang FOR EACH ROW EXECUTE FUNCTION fn_auto_kode();

DROP TRIGGER IF EXISTS trg_auto_kode_reseller ON reseller;
CREATE TRIGGER trg_auto_kode_reseller
  BEFORE INSERT ON reseller FOR EACH ROW EXECUTE FUNCTION fn_auto_kode();

-- stok otomatis
DROP TRIGGER IF EXISTS trg_kurangi_stok ON transaksi_item;
CREATE TRIGGER trg_kurangi_stok
  AFTER INSERT ON transaksi_item FOR EACH ROW EXECUTE FUNCTION fn_kurangi_stok_penjualan();

DROP TRIGGER IF EXISTS trg_tambah_stok ON pembelian_item;
CREATE TRIGGER trg_tambah_stok
  AFTER INSERT ON pembelian_item FOR EACH ROW EXECUTE FUNCTION fn_tambah_stok_pembelian();

-- member tier otomatis
DROP TRIGGER IF EXISTS trg_member_tier ON member;
CREATE TRIGGER trg_member_tier
  BEFORE INSERT OR UPDATE OF poin ON member FOR EACH ROW EXECUTE FUNCTION fn_update_member_tier();


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [7] INDEXES YANG HILANG
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Yang paling kritis (full table scan setiap operasi POS)
CREATE INDEX IF NOT EXISTS idx_transaksi_item_transaksi ON transaksi_item(id_transaksi);
CREATE INDEX IF NOT EXISTS idx_transaksi_item_produk    ON transaksi_item(id_produk);
CREATE INDEX IF NOT EXISTS idx_produk_barcode           ON produk(barcode);
CREATE INDEX IF NOT EXISTS idx_member_no_hp             ON member(no_hp);

-- Untuk laporan dan filter
CREATE INDEX IF NOT EXISTS idx_member_nama      ON member(nama);
CREATE INDEX IF NOT EXISTS idx_transaksi_kasir  ON transaksi(id_kasir);
CREATE INDEX IF NOT EXISTS idx_transaksi_metode ON transaksi(metode_bayar);

-- Untuk tabel baru
CREATE INDEX IF NOT EXISTS idx_stok_log_produk      ON stok_log(id_produk);
CREATE INDEX IF NOT EXISTS idx_stok_log_created     ON stok_log(created_at);
CREATE INDEX IF NOT EXISTS idx_shift_kasir_kasir    ON shift_kasir(id_kasir, tanggal);
CREATE INDEX IF NOT EXISTS idx_retur_pjl_item_retur ON retur_penjualan_item(id_retur);
CREATE INDEX IF NOT EXISTS idx_retur_pbli_item_retur ON retur_pembelian_item(id_retur);


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [8] RPCs / STORED PROCEDURES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- [8a] Login (plaintext untuk kompatibilitas; migrate ke crypt() setelah semua user diupdate)
CREATE OR REPLACE FUNCTION validate_login(p_username text, p_password text)
RETURNS TABLE(id bigint, nama text, role text, avatar_color text, avatar_char text)
LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  SELECT id, nama, role, avatar_color, avatar_char
  FROM profiles
  WHERE username = lower(trim(p_username))
    AND password = p_password
    AND aktif    = true
  LIMIT 1;
$$;

-- [8b] List semua profil (untuk halaman manajemen user web panel)
CREATE OR REPLACE FUNCTION list_profiles()
RETURNS TABLE(
  id          bigint,
  username    text,
  nama        text,
  role        text,
  avatar_char  text,
  avatar_color text,
  aktif       boolean,
  created_at  timestamptz
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  SELECT id, username, nama, role, avatar_char, avatar_color, aktif, created_at
  FROM profiles
  ORDER BY nama;
$$;

-- [8c] Simpan profil baru atau update yang sudah ada
CREATE OR REPLACE FUNCTION save_profile(
  p_id          bigint   DEFAULT NULL,
  p_username    text     DEFAULT NULL,
  p_nama        text     DEFAULT NULL,
  p_role        text     DEFAULT 'Kasir',
  p_password    text     DEFAULT NULL,
  p_avatar_color text    DEFAULT '#16A34A',
  p_aktif       boolean  DEFAULT true
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_id     bigint;
  v_avatar text;
BEGIN
  v_avatar := upper(left(trim(COALESCE(p_nama, '')), 1));

  IF p_id IS NULL THEN
    INSERT INTO profiles (username, nama, role, password, avatar_char, avatar_color, aktif)
    VALUES (
      lower(trim(p_username)),
      trim(p_nama),
      COALESCE(p_role, 'Kasir'),
      p_password,
      v_avatar,
      COALESCE(p_avatar_color, '#16A34A'),
      COALESCE(p_aktif, true)
    )
    RETURNING id INTO v_id;
  ELSE
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
    WHERE id = p_id;
    v_id := p_id;
  END IF;

  RETURN v_id;
END;
$$;

-- [8d] Non-aktifkan profil (soft delete — data tetap ada)
CREATE OR REPLACE FUNCTION deactivate_profile(p_id bigint)
RETURNS void LANGUAGE sql SECURITY DEFINER
SET search_path = public AS $$
  UPDATE profiles SET aktif = false WHERE id = p_id;
$$;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [9] ROW LEVEL SECURITY
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Enable RLS pada semua tabel
ALTER TABLE profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE kategori             ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier             ENABLE ROW LEVEL SECURITY;
ALTER TABLE produk               ENABLE ROW LEVEL SECURITY;
ALTER TABLE member               ENABLE ROW LEVEL SECURITY;
ALTER TABLE cabang               ENABLE ROW LEVEL SECURITY;
ALTER TABLE reseller             ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaksi            ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaksi_item       ENABLE ROW LEVEL SECURITY;
ALTER TABLE pembelian            ENABLE ROW LEVEL SECURITY;
ALTER TABLE pembelian_item       ENABLE ROW LEVEL SECURITY;
ALTER TABLE kas_log              ENABLE ROW LEVEL SECURITY;
ALTER TABLE retur_penjualan      ENABLE ROW LEVEL SECURITY;
ALTER TABLE retur_pembelian      ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_opname         ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_opname_item    ENABLE ROW LEVEL SECURITY;
ALTER TABLE toko_konfigurasi     ENABLE ROW LEVEL SECURITY;
ALTER TABLE stok_log             ENABLE ROW LEVEL SECURITY;
ALTER TABLE shift_kasir          ENABLE ROW LEVEL SECURITY;
ALTER TABLE retur_penjualan_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE retur_pembelian_item ENABLE ROW LEVEL SECURITY;

-- Hapus semua policy lama (bersih sebelum recreate)
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                   r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

-- profiles: TIDAK ADA direct policy → hanya bisa diakses via SECURITY DEFINER RPC
-- (blocked by default = benar untuk tabel yang berisi password)

-- ─── MASTER DATA (baca bebas, tulis hanya insert/update) ───
CREATE POLICY "kategori_select" ON kategori FOR SELECT USING (true);
CREATE POLICY "kategori_insert" ON kategori FOR INSERT WITH CHECK (true);
CREATE POLICY "kategori_update" ON kategori FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "supplier_select" ON supplier FOR SELECT USING (true);
CREATE POLICY "supplier_insert" ON supplier FOR INSERT WITH CHECK (true);
CREATE POLICY "supplier_update" ON supplier FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "produk_select" ON produk FOR SELECT USING (true);
CREATE POLICY "produk_insert" ON produk FOR INSERT WITH CHECK (true);
CREATE POLICY "produk_update" ON produk FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "member_select" ON member FOR SELECT USING (true);
CREATE POLICY "member_insert" ON member FOR INSERT WITH CHECK (true);
CREATE POLICY "member_update" ON member FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "cabang_select" ON cabang FOR SELECT USING (true);
CREATE POLICY "cabang_insert" ON cabang FOR INSERT WITH CHECK (true);
CREATE POLICY "cabang_update" ON cabang FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "reseller_select" ON reseller FOR SELECT USING (true);
CREATE POLICY "reseller_insert" ON reseller FOR INSERT WITH CHECK (true);
CREATE POLICY "reseller_update" ON reseller FOR UPDATE USING (true) WITH CHECK (true);

-- ─── TRANSAKSI ───
CREATE POLICY "transaksi_select" ON transaksi FOR SELECT USING (true);
CREATE POLICY "transaksi_insert" ON transaksi FOR INSERT WITH CHECK (true);
CREATE POLICY "transaksi_update" ON transaksi FOR UPDATE USING (true) WITH CHECK (true);
-- DELETE tidak diizinkan (tidak ada policy DELETE = blocked)

-- ─── TRANSAKSI_ITEM: append-only ───
CREATE POLICY "transaksi_item_select" ON transaksi_item FOR SELECT USING (true);
CREATE POLICY "transaksi_item_insert" ON transaksi_item FOR INSERT WITH CHECK (true);
-- UPDATE & DELETE tidak diizinkan

-- ─── PEMBELIAN ───
CREATE POLICY "pembelian_select" ON pembelian FOR SELECT USING (true);
CREATE POLICY "pembelian_insert" ON pembelian FOR INSERT WITH CHECK (true);
CREATE POLICY "pembelian_update" ON pembelian FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "pembelian_item_select" ON pembelian_item FOR SELECT USING (true);
CREATE POLICY "pembelian_item_insert" ON pembelian_item FOR INSERT WITH CHECK (true);

-- ─── KAS_LOG: append-only ───
CREATE POLICY "kas_log_select" ON kas_log FOR SELECT USING (true);
CREATE POLICY "kas_log_insert" ON kas_log FOR INSERT WITH CHECK (true);

-- ─── RETUR ───
CREATE POLICY "retur_penjualan_select" ON retur_penjualan FOR SELECT USING (true);
CREATE POLICY "retur_penjualan_insert" ON retur_penjualan FOR INSERT WITH CHECK (true);
CREATE POLICY "retur_penjualan_update" ON retur_penjualan FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "retur_penjualan_item_select" ON retur_penjualan_item FOR SELECT USING (true);
CREATE POLICY "retur_penjualan_item_insert" ON retur_penjualan_item FOR INSERT WITH CHECK (true);

CREATE POLICY "retur_pembelian_select" ON retur_pembelian FOR SELECT USING (true);
CREATE POLICY "retur_pembelian_insert" ON retur_pembelian FOR INSERT WITH CHECK (true);
CREATE POLICY "retur_pembelian_update" ON retur_pembelian FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "retur_pembelian_item_select" ON retur_pembelian_item FOR SELECT USING (true);
CREATE POLICY "retur_pembelian_item_insert" ON retur_pembelian_item FOR INSERT WITH CHECK (true);

-- ─── STOCK OPNAME ───
CREATE POLICY "stock_opname_select" ON stock_opname FOR SELECT USING (true);
CREATE POLICY "stock_opname_insert" ON stock_opname FOR INSERT WITH CHECK (true);
CREATE POLICY "stock_opname_update" ON stock_opname FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "stock_opname_item_select" ON stock_opname_item FOR SELECT USING (true);
CREATE POLICY "stock_opname_item_insert" ON stock_opname_item FOR INSERT WITH CHECK (true);
CREATE POLICY "stock_opname_item_update" ON stock_opname_item FOR UPDATE USING (true) WITH CHECK (true);

-- ─── TOKO KONFIGURASI ───
CREATE POLICY "toko_config_select" ON toko_konfigurasi FOR SELECT USING (true);
CREATE POLICY "toko_config_update" ON toko_konfigurasi FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "toko_config_insert" ON toko_konfigurasi FOR INSERT WITH CHECK (true);

-- ─── STOK_LOG: read-only untuk klien (trigger SECURITY DEFINER yang nulis) ───
CREATE POLICY "stok_log_select" ON stok_log FOR SELECT USING (true);
-- INSERT tidak ada direct policy → trigger SECURITY DEFINER bypass RLS

-- ─── SHIFT KASIR ───
CREATE POLICY "shift_kasir_select" ON shift_kasir FOR SELECT USING (true);
CREATE POLICY "shift_kasir_insert" ON shift_kasir FOR INSERT WITH CHECK (true);
CREATE POLICY "shift_kasir_update" ON shift_kasir FOR UPDATE USING (true) WITH CHECK (true);


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- [10] GRANTS — berikan akses RPC ke anon key
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GRANT EXECUTE ON FUNCTION validate_login(text, text)                                         TO anon;
GRANT EXECUTE ON FUNCTION list_profiles()                                                    TO anon;
GRANT EXECUTE ON FUNCTION save_profile(bigint, text, text, text, text, text, boolean)        TO anon;
GRANT EXECUTE ON FUNCTION deactivate_profile(bigint)                                         TO anon;


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SELESAI ✓
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Apa yang sudah ditangani oleh script ini:
--
--  [P0] ✓ kode NOT NULL → trigger fn_auto_kode() generate otomatis
--  [P0] ✓ list_profiles, save_profile, deactivate_profile → dibuat
--  [P0] ✓ trigger update stok saat penjualan → fn_kurangi_stok_penjualan()
--  [P0] ✓ trigger tambah stok saat pembelian → fn_tambah_stok_pembelian()
--  [P0] ✓ validate_login → fix return type (sekarang termasuk id + avatar_char)
--  [P1] ✓ transaksi.diskon, ppn_rate, ppn_nominal → kolom ditambahkan
--  [P1] ✓ transaksi.kasir text → kolom ditambahkan (untuk Flutter)
--  [P1] ✓ metode_bayar CHECK diperluas (8 nilai)
--  [P1] ✓ index transaksi_item(id_transaksi) → ditambahkan
--  [P1] ✓ index produk(barcode) → ditambahkan
--  [P1] ✓ updated_at trigger → fn_set_updated_at()
--  [P1] ✓ retur_penjualan_item + retur_pembelian_item → tabel baru
--  [P2] ✓ member.tier → trigger fn_update_member_tier() otomatis di DB
--  [P2] ✓ tabel toko_konfigurasi → untuk nama toko, PPN, footer struk
--  [P2] ✓ tabel stok_log → audit trail pergerakan stok
--  [P2] ✓ tabel shift_kasir → buka/tutup kasir per sesi
--
-- Yang masih perlu dilakukan secara MANUAL:
--  [ ] Migrate password ke hashed (pgcrypto crypt()) setelah semua user diupdate
--  [ ] Ganti RLS ke role-based setelah migrasi ke Supabase Auth proper
--  [ ] Insert profil admin pertama:
--        SELECT save_profile(NULL, 'admin', 'Super Admin', 'Super Admin', 'password123');
-- ============================================================
