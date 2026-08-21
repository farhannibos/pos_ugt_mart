/* ════════════════════════════════════════════════════════════════════════════
   MIGRASI — Pengajuan lisensi premium otomatis dari aplikasi
   Jalankan blok ini di Supabase SQL Editor SETELAH migration_dev_panel.sql.
   Aman dijalankan berulang (semua statement idempotent).

   Tujuan:
   1. Tambah RPC cek_pengajuan_lisensi_pending() agar aplikasi bisa cek dulu
      apakah toko sudah punya pengajuan yang masih menunggu, tanpa perlu akses
      dev_list_lisensi_requests() (yang mengembalikan data SEMUA toko).
   2. dev_ajukan_lisensi() ditambah guard: tolak pengajuan baru kalau toko
      masih punya pengajuan berstatus 'pending' (mencegah spam/duplikat).
   ════════════════════════════════════════════════════════════════════════════ */

-- 1. Cek status pengajuan pending milik satu toko (dipanggil dari aplikasi)
CREATE OR REPLACE FUNCTION cek_pengajuan_lisensi_pending(p_id_toko bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_req lisensi_request%ROWTYPE;
BEGIN
  SELECT * INTO v_req
  FROM lisensi_request
  WHERE id_toko = p_id_toko AND status = 'pending'
  ORDER BY diajukan_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ada', false);
  END IF;

  RETURN jsonb_build_object(
    'ada',         true,
    'no_invoice',  v_req.no_invoice,
    'durasi_bulan',v_req.durasi_bulan,
    'harga',       v_req.harga,
    'diajukan_at', v_req.diajukan_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION cek_pengajuan_lisensi_pending(bigint) TO anon;

-- 2. Guard di dev_ajukan_lisensi: tolak kalau masih ada pengajuan pending
--    (signature sama persis dengan definisi di migration_dev_panel.sql,
--    jadi CREATE OR REPLACE ini menimpa fungsi yang sama, bukan bikin baru)
CREATE OR REPLACE FUNCTION dev_ajukan_lisensi(
  p_id_toko      bigint,
  p_id_device    text,
  p_durasi_bulan int     DEFAULT 1,
  p_harga        int     DEFAULT 0,
  p_catatan      text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id      bigint;
  v_invoice text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM toko WHERE id = p_id_toko) THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Toko/member tidak ditemukan');
  END IF;
  IF p_id_device IS NULL OR trim(p_id_device) = '' THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'ID Device wajib diisi');
  END IF;
  IF EXISTS (SELECT 1 FROM lisensi_request WHERE id_toko = p_id_toko AND status = 'pending') THEN
    RETURN jsonb_build_object('ok', false, 'pesan', 'Masih ada pengajuan yang menunggu persetujuan admin');
  END IF;

  v_invoice := _next_invoice_number();

  INSERT INTO lisensi_request (id_toko, id_device, durasi_bulan, harga, no_invoice, catatan)
  VALUES (p_id_toko, trim(p_id_device), COALESCE(p_durasi_bulan, 1), COALESCE(p_harga, 0), v_invoice, p_catatan)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'no_invoice', v_invoice, 'pesan', 'Pengajuan berhasil dibuat');
END;
$$;

GRANT EXECUTE ON FUNCTION dev_ajukan_lisensi(bigint, text, int, int, text) TO anon;
