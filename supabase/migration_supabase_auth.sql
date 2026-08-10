-- ════════════════════════════════════════════════════════════════
--  MIGRATION: Supabase Auth Integration — Tenant Isolation via JWT
--  Jalankan di Supabase → SQL Editor → Run
--
--  SEBELUM jalankan ini:
--  1. Supabase Dashboard → Authentication → Providers → Email
--     → nonaktifkan "Confirm email" (supaya signup langsung aktif)
--  2. Pastikan Flutter app dan web panel sudah di-update ke versi
--     yang memanggil supabase.auth.signIn() setelah validate_login
-- ════════════════════════════════════════════════════════════════

-- ── Helper: baca id_toko dari JWT Supabase Auth ────────────────
CREATE OR REPLACE FUNCTION get_my_id_toko()
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'user_metadata'     ->> 'id_toko')::bigint,
    (auth.jwt() -> 'raw_user_meta_data' ->> 'id_toko')::bigint
  )
$$;

GRANT EXECUTE ON FUNCTION get_my_id_toko() TO authenticated, anon;

-- ── PRODUK ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "produk_select" ON produk;
DROP POLICY IF EXISTS "produk_insert" ON produk;
DROP POLICY IF EXISTS "produk_update" ON produk;

CREATE POLICY "produk_select" ON produk
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "produk_insert" ON produk
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "produk_update" ON produk
  FOR UPDATE USING (id_toko = get_my_id_toko())
  WITH CHECK (id_toko = get_my_id_toko());

-- ── TRANSAKSI ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "transaksi_select" ON transaksi;
DROP POLICY IF EXISTS "transaksi_insert" ON transaksi;
DROP POLICY IF EXISTS "transaksi_update" ON transaksi;
DROP POLICY IF EXISTS "block_anon_delete_transaksi" ON transaksi;

CREATE POLICY "transaksi_select" ON transaksi
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "transaksi_insert" ON transaksi
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "transaksi_update" ON transaksi
  FOR UPDATE USING (id_toko = get_my_id_toko())
  WITH CHECK (id_toko = get_my_id_toko());

-- ── TRANSAKSI_ITEM (join ke transaksi untuk cek id_toko) ───────
DROP POLICY IF EXISTS "trx_item_select" ON transaksi_item;
DROP POLICY IF EXISTS "trx_item_insert" ON transaksi_item;

CREATE POLICY "trx_item_select" ON transaksi_item
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM transaksi t
      WHERE t.id = transaksi_item.id_transaksi
        AND t.id_toko = get_my_id_toko()
    )
  );

CREATE POLICY "trx_item_insert" ON transaksi_item
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM transaksi t
      WHERE t.id = transaksi_item.id_transaksi
        AND t.id_toko = get_my_id_toko()
    )
  );

-- ── MEMBER ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "member_select" ON member;
DROP POLICY IF EXISTS "member_insert" ON member;
DROP POLICY IF EXISTS "member_update" ON member;

CREATE POLICY "member_select" ON member
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "member_insert" ON member
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "member_update" ON member
  FOR UPDATE USING (id_toko = get_my_id_toko())
  WITH CHECK (id_toko = get_my_id_toko());

-- ── KATEGORI ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "kategori_select" ON kategori;
DROP POLICY IF EXISTS "kategori_insert" ON kategori;
DROP POLICY IF EXISTS "kategori_update" ON kategori;

-- Kategori global (id_toko NULL) bisa dibaca semua toko
CREATE POLICY "kategori_select" ON kategori
  FOR SELECT USING (id_toko = get_my_id_toko() OR id_toko IS NULL);

CREATE POLICY "kategori_insert" ON kategori
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "kategori_update" ON kategori
  FOR UPDATE USING (id_toko = get_my_id_toko())
  WITH CHECK (id_toko = get_my_id_toko());

-- ── KAS_LOG ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "kas_select" ON kas_log;
DROP POLICY IF EXISTS "kas_insert" ON kas_log;

CREATE POLICY "kas_select" ON kas_log
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "kas_insert" ON kas_log
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

-- ── PROFILES ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_select" ON profiles;

CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (id_toko = get_my_id_toko());

-- ── SUPPLIER ───────────────────────────────────────────────────
ALTER TABLE supplier ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supplier_select" ON supplier;
DROP POLICY IF EXISTS "supplier_insert" ON supplier;
DROP POLICY IF EXISTS "supplier_update" ON supplier;

CREATE POLICY "supplier_select" ON supplier
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "supplier_insert" ON supplier
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());

CREATE POLICY "supplier_update" ON supplier
  FOR UPDATE USING (id_toko = get_my_id_toko())
  WITH CHECK (id_toko = get_my_id_toko());

-- ── PEMBELIAN ──────────────────────────────────────────────────
ALTER TABLE pembelian ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pembelian_select" ON pembelian;
DROP POLICY IF EXISTS "pembelian_insert" ON pembelian;

CREATE POLICY "pembelian_select" ON pembelian
  FOR SELECT USING (id_toko = get_my_id_toko());

CREATE POLICY "pembelian_insert" ON pembelian
  FOR INSERT WITH CHECK (id_toko = get_my_id_toko());
