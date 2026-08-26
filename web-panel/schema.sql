-- ============================================================
--  SKEMA DATABASE TUNGGAL — POS UGT MART
--  Target  : Supabase (PostgreSQL)
--  Versi   : 1.0  |  2026-07-29
--
--  Sumber  :
--    - Flutter models  (product.dart, member.dart, transaction.dart)
--    - HTML admin panel (index.html dummy data)
--
--  Konvensi penamaan:
--    • snake_case untuk semua nama kolom
--    • id bigserial sebagai PK (bukan UUID) agar mudah dibaca
--    • kolom kode (teks) untuk kode bisnis yang tampil di UI
--    • created_at + updated_at di semua tabel utama
-- ============================================================

-- Aktifkan ekstensi jika belum
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- 1. PROFILES  (System Users)
-- ============================================================
-- Catatan: tabel ini adalah profil aplikasi yang terhubung ke
-- auth.users Supabase via kolom auth_id. Password dikelola
-- sepenuhnya oleh Supabase Auth.
-- ============================================================
CREATE TABLE profiles (
  id           bigserial    PRIMARY KEY,
  auth_id      uuid         UNIQUE,                    -- FK ke auth.users.id (Supabase)
  username     text         NOT NULL UNIQUE,            -- HTML: 'user'   → username
  nama         text         NOT NULL,                   -- HTML: 'name'   → nama
  role         text         NOT NULL DEFAULT 'Admin'
               CHECK (role IN ('Owner', 'Admin', 'Kasir')),
  avatar_char  text         NOT NULL DEFAULT '',        -- HTML: 'avatar' → avatar_char
  avatar_color text         NOT NULL DEFAULT '#16A34A', -- HTML: 'avatarColor' → avatar_color
  aktif        boolean      NOT NULL DEFAULT true,
  created_at   timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON TABLE profiles IS 'Akun pengguna sistem POS. Password dikelola Supabase Auth.';


-- ============================================================
-- 2. KATEGORI
-- ============================================================
-- Hanya ada di HTML. Flutter pakai string langsung di produk —
-- Flutter perlu migrasi ke id_kategori (FK ke tabel ini).
-- ============================================================
CREATE TABLE kategori (
  id          bigserial    PRIMARY KEY,
  kode        text         NOT NULL UNIQUE,  -- format: KT-001
  nama        text         NOT NULL,          -- HTML: 'nama_kategori' → nama
  deskripsi   text,
  status      text         NOT NULL DEFAULT 'Aktif'
              CHECK (status IN ('Aktif', 'Non-aktif')),
  created_at  timestamptz  NOT NULL DEFAULT now(),
  updated_at  timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON COLUMN kategori.kode IS 'Kode bisnis kategori, format KT-XXX';


-- ============================================================
-- 3. SUPPLIER
-- ============================================================
-- Ada di navigasi HTML, belum diimplementasikan.
-- Flutter belum punya model ini.
-- ============================================================
CREATE TABLE supplier (
  id          bigserial    PRIMARY KEY,
  kode        text         NOT NULL UNIQUE,  -- format: SUP-001
  nama        text         NOT NULL,
  kontak      text,
  alamat      text,
  saldo_hutang integer     NOT NULL DEFAULT 0,  -- sisa hutang ke supplier
  status      text         NOT NULL DEFAULT 'Aktif'
              CHECK (status IN ('Aktif', 'Non-aktif')),
  created_at  timestamptz  NOT NULL DEFAULT now(),
  updated_at  timestamptz  NOT NULL DEFAULT now()
);


-- ============================================================
-- 4. PRODUK
-- ============================================================
-- Flutter   : Product (id, nama, kategori:String, harga, stok, barcode)
-- HTML      : Barang  (kode, nama_barang, kategori:FK, satuan,
--                      harga_beli, harga_jual, stok, status)
--
-- Keputusan field:
--   nama_barang (HTML)  → nama          (Flutter sudah pakai 'nama')
--   kategori:String     → id_kategori   (FK; Flutter perlu diubah)
--   harga (Flutter)     → harga_jual    (HTML lebih lengkap; tambah harga_beli)
--   [baru] satuan       → satuan        (dari HTML, tambahkan di Flutter)
--   [baru] stok_minimum → stok_minimum  (implied di HTML low-stock widget)
--   [baru] status       → status        (dari HTML; Flutter belum punya)
--   barcode (Flutter)   → barcode       (pertahankan)
-- ============================================================
CREATE TABLE produk (
  id            bigserial    PRIMARY KEY,
  kode          text         NOT NULL UNIQUE,  -- format: BRG-001
  nama          text         NOT NULL,
  id_kategori   bigint       REFERENCES kategori(id) ON DELETE SET NULL,
  satuan        text         NOT NULL DEFAULT 'Pcs',  -- Botol, Kg, Pcs, Karung, dll
  harga_beli    integer      NOT NULL DEFAULT 0,
  harga_jual    integer      NOT NULL DEFAULT 0,
  stok          integer      NOT NULL DEFAULT 0,
  stok_minimum  integer      NOT NULL DEFAULT 10,
  barcode       text,
  status        text         NOT NULL DEFAULT 'Aktif'
                CHECK (status IN ('Aktif', 'Non-aktif')),
  created_at    timestamptz  NOT NULL DEFAULT now(),
  updated_at    timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON COLUMN produk.harga_jual IS 'Harga yang ditampilkan di POS kasir (Flutter: harga)';
COMMENT ON COLUMN produk.stok_minimum IS 'Batas stok rendah; Flutter: isLowStock = stok <= stok_minimum';


-- ============================================================
-- 5. MEMBER
-- ============================================================
-- Flutter : Member (id, nama, hp, tier, poin, spend)
-- HTML    : halaman belum diimplementasikan
--
-- Keputusan field:
--   hp (Flutter)    → no_hp        (lebih standar)
--   spend (Flutter) → total_spend  (lebih deskriptif)
--   [baru] kode     → kode         (format MBR-001, konsisten dengan entitas lain)
--   [baru] aktif    → aktif        (untuk soft-delete)
-- ============================================================
CREATE TABLE member (
  id           bigserial    PRIMARY KEY,
  kode         text         NOT NULL UNIQUE,  -- format: MBR-001
  nama         text         NOT NULL,
  no_hp        text,                           -- Flutter: 'hp' → no_hp
  tier         text         NOT NULL DEFAULT 'Reguler'
               CHECK (tier IN ('Gold', 'Silver', 'Reguler')),
  poin         integer      NOT NULL DEFAULT 0,
  total_spend  integer      NOT NULL DEFAULT 0,  -- Flutter: 'spend' → total_spend
  aktif        boolean      NOT NULL DEFAULT true,
  created_at   timestamptz  NOT NULL DEFAULT now(),
  updated_at   timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON COLUMN member.total_spend IS 'Total belanja kumulatif dalam Rupiah (Flutter: spend)';


-- ============================================================
-- 6. CABANG
-- ============================================================
-- Ada di navigasi HTML sebagai sub-entitas Pelanggan.
-- Flutter belum punya model ini.
-- ============================================================
CREATE TABLE cabang (
  id          bigserial    PRIMARY KEY,
  kode        text         NOT NULL UNIQUE,  -- format: CBG-001
  nama        text         NOT NULL,
  alamat      text,
  kontak      text,
  aktif       boolean      NOT NULL DEFAULT true,
  created_at  timestamptz  NOT NULL DEFAULT now()
);


-- ============================================================
-- 7. RESELLER
-- ============================================================
-- Ada di navigasi HTML sebagai sub-entitas Pelanggan.
-- Flutter belum punya model ini.
-- ============================================================
CREATE TABLE reseller (
  id          bigserial    PRIMARY KEY,
  kode        text         NOT NULL UNIQUE,  -- format: RSL-001
  nama        text         NOT NULL,
  no_hp       text,
  alamat      text,
  diskon_pct  numeric(5,2) NOT NULL DEFAULT 0,  -- persentase diskon khusus reseller
  aktif       boolean      NOT NULL DEFAULT true,
  created_at  timestamptz  NOT NULL DEFAULT now()
);


-- ============================================================
-- 8. TRANSAKSI
-- ============================================================
-- Flutter : Transaction (id:String TRX-..., jam:String, metode,
--                        total, items:int, status, customer:String)
-- HTML    : kolom no_faktur (#INV-XXXX), pelanggan, total, status
--
-- Keputusan field:
--   id TRX-YYYYMMDD-NNN (Flutter)
--   + no_faktur #INV-XXXX (HTML)     → no_faktur, format: INV-YYYYMMDD-NNN
--   customer (Flutter)               → pelanggan  (HTML sudah pakai 'pelanggan')
--   jam:String HH:mm (Flutter)       → tanggal + jam (pisah agar bisa query range)
--   items:int (Flutter)              → jumlah_item  (lebih eksplisit)
--   metode (Flutter)                 → metode_bayar (lebih eksplisit)
--   status: Lunas|Pending (Flutter)
--         + Lunas|Piutang|Proses (HTML) → gabung semua nilai
-- ============================================================
CREATE TABLE transaksi (
  id             bigserial    PRIMARY KEY,
  no_faktur      text         NOT NULL UNIQUE,  -- format: INV-YYYYMMDD-NNN
  id_member      bigint       REFERENCES member(id) ON DELETE SET NULL,
  id_cabang      bigint       REFERENCES cabang(id) ON DELETE SET NULL,
  id_reseller    bigint       REFERENCES reseller(id) ON DELETE SET NULL,
  pelanggan      text         NOT NULL DEFAULT 'Umum',  -- Flutter: 'customer' → pelanggan
  tanggal        date         NOT NULL DEFAULT CURRENT_DATE,
  jam            time         NOT NULL DEFAULT CURRENT_TIME,  -- Flutter: String HH:mm → time
  metode_bayar   text         NOT NULL DEFAULT 'Tunai'         -- Flutter: 'metode' → metode_bayar
                 CHECK (metode_bayar IN ('Tunai', 'QRIS', 'EDC BCA', 'Voucher')),
  total          integer      NOT NULL DEFAULT 0,
  jumlah_item    integer      NOT NULL DEFAULT 0,   -- Flutter: 'items' → jumlah_item
  status         text         NOT NULL DEFAULT 'Lunas'
                 CHECK (status IN ('Lunas', 'Piutang', 'Pending', 'Proses')),
  id_kasir       bigint       REFERENCES profiles(id) ON DELETE SET NULL,
  created_at     timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON COLUMN transaksi.pelanggan IS 'Nama tampilan pelanggan (Flutter: customer). NULL-safe: isi "Umum" jika bukan member.';
COMMENT ON COLUMN transaksi.jumlah_item IS 'Jumlah baris item (Flutter: items)';


-- ============================================================
-- 9. TRANSAKSI_ITEM  (CartItem)
-- ============================================================
-- Flutter : CartItem (productId, nama, harga, qty)
-- HTML    : tidak ada tabel item terpisah (hanya ringkasan)
--
-- Keputusan field:
--   productId (Flutter) → id_produk
--   nama (Flutter)      → nama_produk  (snapshot; tidak rename produk = data rusak)
--   [computed] subtotal → GENERATED ALWAYS AS (harga * qty) STORED
-- ============================================================
CREATE TABLE transaksi_item (
  id             bigserial    PRIMARY KEY,
  id_transaksi   bigint       NOT NULL REFERENCES transaksi(id) ON DELETE CASCADE,
  id_produk      bigint       REFERENCES produk(id) ON DELETE SET NULL,  -- Flutter: productId
  nama_produk    text         NOT NULL,   -- snapshot nama saat transaksi
  harga          integer      NOT NULL,
  qty            integer      NOT NULL DEFAULT 1,
  subtotal       integer      GENERATED ALWAYS AS (harga * qty) STORED,
  created_at     timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON COLUMN transaksi_item.nama_produk IS 'Snapshot nama produk saat transaksi agar tidak berubah jika produk diedit.';
COMMENT ON COLUMN transaksi_item.subtotal    IS 'Computed: harga × qty. Flutter getter subtotal tetap relevan.';


-- ============================================================
-- 10. PEMBELIAN  (Purchase Order ke Supplier)
-- ============================================================
-- Ada di navigasi HTML. Flutter belum punya model ini.
-- ============================================================
CREATE TABLE pembelian (
  id            bigserial    PRIMARY KEY,
  no_faktur     text         NOT NULL UNIQUE,  -- format: PO-YYYYMMDD-NNN
  id_supplier   bigint       REFERENCES supplier(id) ON DELETE SET NULL,
  tanggal       date         NOT NULL DEFAULT CURRENT_DATE,
  total         integer      NOT NULL DEFAULT 0,
  status        text         NOT NULL DEFAULT 'Lunas'
                CHECK (status IN ('Lunas', 'Hutang', 'Pending')),
  id_operator   bigint       REFERENCES profiles(id) ON DELETE SET NULL,
  created_at    timestamptz  NOT NULL DEFAULT now()
);

CREATE TABLE pembelian_item (
  id             bigserial    PRIMARY KEY,
  id_pembelian   bigint       NOT NULL REFERENCES pembelian(id) ON DELETE CASCADE,
  id_produk      bigint       REFERENCES produk(id) ON DELETE SET NULL,
  nama_produk    text         NOT NULL,
  harga_beli     integer      NOT NULL,
  qty            integer      NOT NULL DEFAULT 1,
  subtotal       integer      GENERATED ALWAYS AS (harga_beli * qty) STORED
);


-- ============================================================
-- 11. KAS_LOG
-- ============================================================
-- Flutter : KasLog (ket, jam:String, nominal, tipe:'masuk'|'keluar')
-- HTML    : halaman kas-kasir ada di nav, belum diimplementasikan
--
-- Keputusan field:
--   ket (Flutter)       → keterangan  (tidak disingkat)
--   jam:String (Flutter)→ tanggal + jam (konsisten dengan transaksi)
--   [baru] id_kasir     → FK ke profiles
-- ============================================================
CREATE TABLE kas_log (
  id           bigserial    PRIMARY KEY,
  keterangan   text         NOT NULL,          -- Flutter: 'ket' → keterangan
  tanggal      date         NOT NULL DEFAULT CURRENT_DATE,
  jam          time         NOT NULL DEFAULT CURRENT_TIME,  -- Flutter: String HH:mm → time
  nominal      integer      NOT NULL,
  tipe         text         NOT NULL
               CHECK (tipe IN ('masuk', 'keluar')),
  id_kasir     bigint       REFERENCES profiles(id) ON DELETE SET NULL,
  created_at   timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON COLUMN kas_log.keterangan IS 'Flutter model field: ket';


-- ============================================================
-- 12. RETUR_PENJUALAN
-- ============================================================
-- Ada di navigasi HTML. Flutter belum punya model ini.
-- ============================================================
CREATE TABLE retur_penjualan (
  id              bigserial    PRIMARY KEY,
  no_retur        text         NOT NULL UNIQUE,  -- format: RJ-YYYYMMDD-NNN
  id_transaksi    bigint       REFERENCES transaksi(id) ON DELETE SET NULL,
  tanggal         date         NOT NULL DEFAULT CURRENT_DATE,
  alasan          text,
  total_retur     integer      NOT NULL DEFAULT 0,
  status          text         NOT NULL DEFAULT 'Diproses'
                  CHECK (status IN ('Diproses', 'Selesai', 'Ditolak')),
  created_at      timestamptz  NOT NULL DEFAULT now()
);


-- ============================================================
-- 13. RETUR_PEMBELIAN
-- ============================================================
-- Ada di navigasi HTML. Flutter belum punya model ini.
-- ============================================================
CREATE TABLE retur_pembelian (
  id              bigserial    PRIMARY KEY,
  no_retur        text         NOT NULL UNIQUE,  -- format: RB-YYYYMMDD-NNN
  id_pembelian    bigint       REFERENCES pembelian(id) ON DELETE SET NULL,
  tanggal         date         NOT NULL DEFAULT CURRENT_DATE,
  alasan          text,
  total_retur     integer      NOT NULL DEFAULT 0,
  status          text         NOT NULL DEFAULT 'Diproses'
                  CHECK (status IN ('Diproses', 'Selesai', 'Ditolak')),
  created_at      timestamptz  NOT NULL DEFAULT now()
);


-- ============================================================
-- 14. STOCK_OPNAME
-- ============================================================
-- Ada di navigasi HTML. Flutter belum punya model ini.
-- ============================================================
CREATE TABLE stock_opname (
  id           bigserial    PRIMARY KEY,
  no_opname    text         NOT NULL UNIQUE,
  tanggal      date         NOT NULL DEFAULT CURRENT_DATE,
  catatan      text,
  status       text         NOT NULL DEFAULT 'Draft'
               CHECK (status IN ('Draft', 'Selesai')),
  id_operator  bigint       REFERENCES profiles(id) ON DELETE SET NULL,
  created_at   timestamptz  NOT NULL DEFAULT now()
);


-- ============================================================
-- INDEXES  (kolom yang sering dipakai untuk filter/join)
-- ============================================================
CREATE INDEX idx_produk_kategori   ON produk(id_kategori);
CREATE INDEX idx_produk_status     ON produk(status);
CREATE INDEX idx_transaksi_tanggal ON transaksi(tanggal);
CREATE INDEX idx_transaksi_status  ON transaksi(status);
CREATE INDEX idx_transaksi_member  ON transaksi(id_member);
CREATE INDEX idx_kas_log_tanggal   ON kas_log(tanggal);
CREATE INDEX idx_pembelian_tanggal ON pembelian(tanggal);


-- ============================================================
--  MIGRASI v1.2  |  2026-08-04
--  Ubah sistem role: Super Admin → Owner, Gudang dihapus, Admin baru.
--  Jalankan blok ini di Supabase SQL Editor.
-- ============================================================

-- 1. Hapus constraint lama
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- 2. Migrasi data existing
UPDATE profiles SET role = 'Owner' WHERE role = 'Super Admin';
UPDATE profiles SET role = 'Admin' WHERE role = 'Gudang';
-- Kasir tetap 'Kasir'

-- 3. Pasang constraint baru + default baru
ALTER TABLE profiles ALTER COLUMN role SET DEFAULT 'Admin';
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('Owner', 'Admin', 'Kasir'));

-- ============================================================
--  MIGRASI v1.1  |  2026-08-03
--  Melengkapi skema agar panel admin bisa mencatat:
--    • cicilan piutang (transaksi) dan cicilan hutang (pembelian)
--    • jatuh tempo tagihan
--    • email/kontak entitas master yang dipakai form panel
--    • riwayat pembayaran per tagihan
--  Aman dijalankan berulang (IF NOT EXISTS).
-- ============================================================

-- 1. Cicilan & jatuh tempo PIUTANG (ada di tabel transaksi)
ALTER TABLE transaksi  ADD COLUMN IF NOT EXISTS terbayar     integer NOT NULL DEFAULT 0;
ALTER TABLE transaksi  ADD COLUMN IF NOT EXISTS jatuh_tempo  date;
ALTER TABLE transaksi  ADD COLUMN IF NOT EXISTS kasir        text;

-- 2. Cicilan & jatuh tempo HUTANG (ada di tabel pembelian)
ALTER TABLE pembelian  ADD COLUMN IF NOT EXISTS terbayar     integer NOT NULL DEFAULT 0;
ALTER TABLE pembelian  ADD COLUMN IF NOT EXISTS jatuh_tempo  date;
ALTER TABLE pembelian  ADD COLUMN IF NOT EXISTS keterangan   text;

-- 3. Kolom master yang dipakai form panel tapi belum ada di skema awal
ALTER TABLE supplier   ADD COLUMN IF NOT EXISTS email        text;
ALTER TABLE member     ADD COLUMN IF NOT EXISTS email        text;
ALTER TABLE member     ADD COLUMN IF NOT EXISTS alamat       text;
ALTER TABLE cabang     ADD COLUMN IF NOT EXISTS pic          text;
ALTER TABLE reseller   ADD COLUMN IF NOT EXISTS limit_kredit integer NOT NULL DEFAULT 0;
ALTER TABLE stock_opname ADD COLUMN IF NOT EXISTS petugas    text;
ALTER TABLE stock_opname ADD COLUMN IF NOT EXISTS jumlah_item integer NOT NULL DEFAULT 0;
ALTER TABLE stock_opname ADD COLUMN IF NOT EXISTS selisih    integer NOT NULL DEFAULT 0;

-- 4. Retur: simpan supplier/pelanggan sebagai snapshot teks + nilai total
ALTER TABLE retur_penjualan ADD COLUMN IF NOT EXISTS pelanggan  text;
ALTER TABLE retur_penjualan ADD COLUMN IF NOT EXISTS no_faktur  text;
ALTER TABLE retur_pembelian ADD COLUMN IF NOT EXISTS supplier   text;
ALTER TABLE retur_pembelian ADD COLUMN IF NOT EXISTS no_po      text;

-- 5. Riwayat pembayaran cicilan (hutang & piutang jadi satu tabel)
CREATE TABLE IF NOT EXISTS pembayaran (
  id            bigserial    PRIMARY KEY,
  jenis         text         NOT NULL CHECK (jenis IN ('piutang', 'hutang')),
  id_transaksi  bigint       REFERENCES transaksi(id) ON DELETE CASCADE,
  id_pembelian  bigint       REFERENCES pembelian(id) ON DELETE CASCADE,
  no_referensi  text         NOT NULL,          -- no_faktur / no_po, agar tetap terbaca
  nominal       integer      NOT NULL,
  metode        text         NOT NULL DEFAULT 'Tunai',
  tanggal       date         NOT NULL DEFAULT CURRENT_DATE,
  id_operator   bigint       REFERENCES profiles(id) ON DELETE SET NULL,
  created_at    timestamptz  NOT NULL DEFAULT now(),
  CHECK (nominal > 0),
  CHECK ((jenis = 'piutang' AND id_pembelian IS NULL)
      OR (jenis = 'hutang'  AND id_transaksi IS NULL))
);

CREATE INDEX IF NOT EXISTS idx_pembayaran_ref ON pembayaran(no_referensi);

-- 6. Penyesuaian stok manual (di navigasi HTML, belum punya tabel)
CREATE TABLE IF NOT EXISTS adjustment_stok (
  id           bigserial    PRIMARY KEY,
  id_produk    bigint       REFERENCES produk(id) ON DELETE SET NULL,
  nama_produk  text         NOT NULL,
  stok_sistem  integer      NOT NULL DEFAULT 0,
  stok_fisik   integer      NOT NULL DEFAULT 0,
  selisih      integer      GENERATED ALWAYS AS (stok_fisik - stok_sistem) STORED,
  keterangan   text,
  petugas      text,
  tanggal      date         NOT NULL DEFAULT CURRENT_DATE,
  created_at   timestamptz  NOT NULL DEFAULT now(),
  -- Sesi stock opname yang jadi alasan penyesuaian ini dibuat (nullable —
  -- penyesuaian ad-hoc di luar sesi opname tetap boleh).
  id_opname    bigint       REFERENCES stock_opname(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_adj_tanggal ON adjustment_stok(tanggal);
CREATE INDEX IF NOT EXISTS idx_adj_stok_opname ON adjustment_stok(id_opname);

-- 7. Status pembelian perlu nilai 'Lunas'/'Hutang'/'Pending' — sudah sesuai.
--    Status transaksi perlu 'Piutang' — sudah sesuai.

-- ============================================================
--  QR LOGIN  |  2026-08-04
--  Login web panel via QR Code seperti WhatsApp Web.
--  Jalankan blok ini di Supabase SQL Editor.
-- ============================================================

-- 1. Tabel sesi QR
CREATE TABLE IF NOT EXISTS qr_sessions (
  id          bigserial    PRIMARY KEY,
  token       text         NOT NULL UNIQUE
              DEFAULT encode(gen_random_bytes(32), 'hex'),
  status      text         NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending', 'scanned', 'expired')),
  id_profile  bigint       REFERENCES profiles(id) ON DELETE CASCADE,
  created_at  timestamptz  NOT NULL DEFAULT now(),
  expires_at  timestamptz  NOT NULL DEFAULT now() + interval '5 minutes'
);

CREATE INDEX IF NOT EXISTS idx_qr_token  ON qr_sessions(token);
CREATE INDEX IF NOT EXISTS idx_qr_status ON qr_sessions(status);

-- ============================================================
-- 2. RPC: generate_qr_token
--    Dipanggil web panel saat halaman login dibuka.
--    Membuat token baru dan mengembalikannya.
-- ============================================================
CREATE OR REPLACE FUNCTION generate_qr_token()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token text;
BEGIN
  -- Bersihkan sesi lama yang sudah expired
  DELETE FROM qr_sessions WHERE expires_at < now();

  -- Buat token baru
  v_token := encode(gen_random_bytes(32), 'hex');
  INSERT INTO qr_sessions (token) VALUES (v_token);

  RETURN v_token;
END;
$$;

-- ============================================================
-- 3. RPC: scan_qr_token
--    Dipanggil mobile app setelah scan QR.
--    User sudah login di mobile — cukup kirim token + username.
-- ============================================================
CREATE OR REPLACE FUNCTION scan_qr_token(p_token text, p_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_profile  profiles%ROWTYPE;
  v_session  qr_sessions%ROWTYPE;
BEGIN
  -- Cek token valid, masih pending, belum expired
  SELECT * INTO v_session
  FROM qr_sessions
  WHERE token = p_token
    AND status = 'pending'
    AND expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'QR tidak valid atau sudah expired');
  END IF;

  -- Cari profil berdasarkan username
  SELECT * INTO v_profile
  FROM profiles
  WHERE username = p_username AND aktif = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'User tidak ditemukan');
  END IF;

  -- Tandai QR sebagai sudah di-scan
  UPDATE qr_sessions
  SET status = 'scanned', id_profile = v_profile.id
  WHERE token = p_token;

  RETURN jsonb_build_object('ok', true, 'pesan', 'QR berhasil di-scan');
END;
$$;

-- ============================================================
-- 4. RPC: check_qr_status
--    Dipanggil web panel tiap 2 detik (polling).
--    Mengembalikan status QR + data user jika sudah di-scan.
-- ============================================================
CREATE OR REPLACE FUNCTION check_qr_status(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session  qr_sessions%ROWTYPE;
  v_profile  profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_session FROM qr_sessions WHERE token = p_token;

  -- Token tidak ditemukan atau sudah dihapus
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'expired');
  END IF;

  -- Expired
  IF v_session.expires_at < now() OR v_session.status = 'expired' THEN
    UPDATE qr_sessions SET status = 'expired' WHERE token = p_token;
    RETURN jsonb_build_object('status', 'expired');
  END IF;

  -- Masih menunggu scan
  IF v_session.status = 'pending' THEN
    RETURN jsonb_build_object('status', 'pending');
  END IF;

  -- Sudah di-scan — ambil data user
  SELECT * INTO v_profile FROM profiles WHERE id = v_session.id_profile;

  -- Hapus sesi setelah dibaca supaya tidak bisa dipakai ulang
  DELETE FROM qr_sessions WHERE token = p_token;

  RETURN jsonb_build_object(
    'status',       'scanned',
    'nama',         v_profile.nama,
    'username',     v_profile.username,
    'role',         v_profile.role,
    'avatar_color', v_profile.avatar_color
  );
END;
$$;

-- ============================================================
--  MIGRASI v2.0  |  SISTEM BERLANGGANAN
--  Jalankan blok ini di Supabase SQL Editor (aman diulang).
-- ============================================================

-- 1. Tabel toko
CREATE TABLE IF NOT EXISTS toko (
  id          bigserial    PRIMARY KEY,
  nama_toko   text         NOT NULL,
  alamat      text,
  no_hp       text,
  plan        text         NOT NULL DEFAULT 'free'
              CHECK (plan IN ('free', 'premium')),
  expired_at  date,
  created_at  timestamptz  NOT NULL DEFAULT now()
);

-- 2. Tabel log langganan
CREATE TABLE IF NOT EXISTS langganan_log (
  id          bigserial    PRIMARY KEY,
  id_toko     bigint       NOT NULL REFERENCES toko(id) ON DELETE CASCADE,
  mulai       date         NOT NULL,
  selesai     date         NOT NULL,
  nominal     integer      NOT NULL DEFAULT 0,
  keterangan  text,
  created_by  text,
  created_at  timestamptz  NOT NULL DEFAULT now()
);

-- 3. Tambah id_toko ke profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash text;

-- 4. RPC: register_toko
--    Dipanggil saat pengguna baru mendaftarkan tokonya.
CREATE OR REPLACE FUNCTION register_toko(
  p_nama_toko text,
  p_alamat    text,
  p_no_hp     text,
  p_nama      text,
  p_username  text,
  p_password  text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toko_id bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM profiles WHERE username = p_username) THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Username sudah digunakan');
  END IF;

  INSERT INTO toko (nama_toko, alamat, no_hp)
  VALUES (p_nama_toko, p_alamat, p_no_hp)
  RETURNING id INTO v_toko_id;

  INSERT INTO profiles (id_toko, username, password_hash, nama, role, aktif)
  VALUES (
    v_toko_id,
    p_username,
    crypt(p_password, gen_salt('bf')),
    p_nama,
    'Owner',
    true
  );

  RETURN jsonb_build_object('ok', true, 'id_toko', v_toko_id, 'pesan', 'Toko berhasil didaftarkan');
END;
$$;

-- 5. RPC: aktivasi_premium
--    Dijalankan oleh admin untuk mengaktifkan langganan premium.
CREATE OR REPLACE FUNCTION aktivasi_premium(
  p_id_toko    bigint,
  p_bulan      int     DEFAULT 1,
  p_nominal    int     DEFAULT 0,
  p_keterangan text    DEFAULT NULL,
  p_admin      text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_mulai   date := CURRENT_DATE;
  v_selesai date;
  v_current_expired date;
  v_current_plan    text;
BEGIN
  SELECT plan, expired_at INTO v_current_plan, v_current_expired
  FROM toko WHERE id = p_id_toko;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Toko tidak ditemukan');
  END IF;

  -- Perpanjang dari expired_at jika masih aktif
  IF v_current_plan = 'premium' AND v_current_expired IS NOT NULL AND v_current_expired >= CURRENT_DATE THEN
    v_mulai := v_current_expired + 1;
  END IF;

  v_selesai := v_mulai + (p_bulan * 30) - 1;

  UPDATE toko SET plan = 'premium', expired_at = v_selesai WHERE id = p_id_toko;

  INSERT INTO langganan_log (id_toko, mulai, selesai, nominal, keterangan, created_by)
  VALUES (p_id_toko, v_mulai, v_selesai, p_nominal, p_keterangan, p_admin);

  RETURN jsonb_build_object(
    'ok',      true,
    'selesai', v_selesai::text,
    'pesan',   'Premium aktif sampai ' || to_char(v_selesai, 'DD Mon YYYY')
  );
END;
$$;

-- 6. RPC: validate_login (update — tambah info plan)
CREATE OR REPLACE FUNCTION validate_login(p_username text, p_password text)
RETURNS TABLE(
  nama        text,
  role        text,
  avatar_color text,
  id_toko     bigint,
  nama_toko   text,
  plan        text,
  expired_at  date
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.nama,
    p.role,
    p.avatar_color,
    t.id                                           AS id_toko,
    COALESCE(t.nama_toko, 'UGT MART')             AS nama_toko,
    CASE
      WHEN t.plan = 'premium'
       AND (t.expired_at IS NULL OR t.expired_at >= CURRENT_DATE)
      THEN 'premium'
      ELSE 'free'
    END                                            AS plan,
    t.expired_at
  FROM profiles p
  LEFT JOIN toko t ON p.id_toko = t.id
  WHERE p.username = p_username
    AND p.password_hash = crypt(p_password, p.password_hash)
    AND p.aktif = true;
END;
$$;

-- 7. RPC: list_toko (untuk panel admin aktivasi langganan)
CREATE OR REPLACE FUNCTION list_toko_langganan()
RETURNS TABLE(
  id_toko    bigint,
  nama_toko  text,
  no_hp      text,
  plan       text,
  expired_at date,
  created_at timestamptz,
  owner_nama text,
  owner_user text
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id,
    t.nama_toko,
    t.no_hp,
    t.plan,
    t.expired_at,
    t.created_at,
    p.nama,
    p.username
  FROM toko t
  LEFT JOIN profiles p ON p.id_toko = t.id AND p.role = 'Owner'
  ORDER BY t.created_at DESC;
END;
$$;


/* ════════════════════════════════════════════════════════════════════════════
   MIGRASI v2.1 — Multi-tenancy Web Panel
   Tambah kolom id_toko ke semua tabel data agar setiap toko hanya
   melihat datanya sendiri saat menggunakan web admin panel.

   Jalankan blok ini di Supabase SQL Editor setelah MIGRASI v2.0.
   Gunakan "Run" satu blok sekaligus jika ada error.
   ════════════════════════════════════════════════════════════════════════════ */

-- 1. Kolom id_toko untuk tabel utama yang dipakai Flutter + Web Panel
ALTER TABLE produk          ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE member          ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE transaksi       ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE supplier        ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE pembelian       ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;

-- 2. Kolom id_toko untuk tabel Web Panel v1.1
ALTER TABLE cabang          ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE reseller        ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE retur_penjualan ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE retur_pembelian ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE kas_log         ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE stock_opname    ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE adjustment_stok ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;
ALTER TABLE pembayaran      ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE;

-- 3. Tabel baru (jika sudah dimigrasi dari v1.1)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stok_log') THEN
    EXECUTE 'ALTER TABLE stok_log ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'shift_kasir') THEN
    EXECUTE 'ALTER TABLE shift_kasir ADD COLUMN IF NOT EXISTS id_toko bigint REFERENCES toko(id) ON DELETE CASCADE';
  END IF;
END $$;

-- 4. Indeks performa
CREATE INDEX IF NOT EXISTS idx_produk_toko      ON produk(id_toko);
CREATE INDEX IF NOT EXISTS idx_member_toko      ON member(id_toko);
CREATE INDEX IF NOT EXISTS idx_transaksi_toko   ON transaksi(id_toko);
CREATE INDEX IF NOT EXISTS idx_supplier_toko    ON supplier(id_toko);
CREATE INDEX IF NOT EXISTS idx_pembelian_toko   ON pembelian(id_toko);
CREATE INDEX IF NOT EXISTS idx_cabang_toko      ON cabang(id_toko);
CREATE INDEX IF NOT EXISTS idx_reseller_toko    ON reseller(id_toko);
CREATE INDEX IF NOT EXISTS idx_retur_jual_toko  ON retur_penjualan(id_toko);
CREATE INDEX IF NOT EXISTS idx_retur_beli_toko  ON retur_pembelian(id_toko);
CREATE INDEX IF NOT EXISTS idx_kas_log_toko     ON kas_log(id_toko);
CREATE INDEX IF NOT EXISTS idx_opname_toko      ON stock_opname(id_toko);
CREATE INDEX IF NOT EXISTS idx_adj_stok_toko    ON adjustment_stok(id_toko);
CREATE INDEX IF NOT EXISTS idx_pembayaran_toko  ON pembayaran(id_toko);

-- 5. Isi id_toko untuk data lama (set ke toko id=1 sebagai default)
-- Ganti angka 1 dengan id toko yang sesuai jika berbeda.
UPDATE produk          SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE member          SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE transaksi       SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE supplier        SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE pembelian       SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE cabang          SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE reseller        SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE retur_penjualan SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE retur_pembelian SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE kas_log         SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE stock_opname    SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE adjustment_stok SET id_toko = 1 WHERE id_toko IS NULL;
UPDATE pembayaran      SET id_toko = 1 WHERE id_toko IS NULL;
