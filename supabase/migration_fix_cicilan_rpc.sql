-- FIX: RPC catat_cicilan untuk pelunasan piutang & hutang
-- Menggantikan INSERT pembayaran + UPDATE transaksi/pembelian langsung
-- yang bergantung pada JWT. RPC ini SECURITY DEFINER sehingga
-- tidak perlu JWT punya id_toko.
-- Jalankan di Supabase -> SQL Editor -> Run

CREATE OR REPLACE FUNCTION catat_cicilan(
  p_jenis        text,
  p_id_induk     bigint,
  p_id_toko      bigint,
  p_no_referensi text,
  p_terbayar     integer,
  p_status       text,
  p_nominal      integer,
  p_metode       text,
  p_tanggal      date
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_toko_match boolean := false;
BEGIN
  -- Validasi: pastikan id_induk memang milik p_id_toko
  IF p_jenis = 'piutang' THEN
    SELECT (id_toko = p_id_toko) INTO v_toko_match
    FROM transaksi WHERE id = p_id_induk;
  ELSE
    SELECT (id_toko = p_id_toko) INTO v_toko_match
    FROM pembelian WHERE id = p_id_induk;
  END IF;

  IF NOT COALESCE(v_toko_match, false) THEN
    RETURN false;
  END IF;

  -- INSERT riwayat pembayaran
  INSERT INTO pembayaran (jenis, no_referensi, nominal, metode, tanggal, id_toko,
                          id_transaksi, id_pembelian)
  VALUES (
    p_jenis,
    p_no_referensi,
    p_nominal,
    p_metode,
    p_tanggal,
    p_id_toko,
    CASE WHEN p_jenis = 'piutang' THEN p_id_induk ELSE NULL END,
    CASE WHEN p_jenis = 'hutang'  THEN p_id_induk ELSE NULL END
  );

  -- UPDATE terbayar & status di transaksi atau pembelian
  IF p_jenis = 'piutang' THEN
    UPDATE transaksi
    SET terbayar = p_terbayar, status = p_status
    WHERE id = p_id_induk AND id_toko = p_id_toko;
  ELSE
    UPDATE pembelian
    SET terbayar = p_terbayar, status = p_status
    WHERE id = p_id_induk AND id_toko = p_id_toko;
  END IF;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION catat_cicilan(text, bigint, bigint, text, integer, text, integer, text, date) TO anon;
