/* ════════════════════════════════════════════════════════════════════════════
   FIX — grafik "Ringkasan Statistik" di dashboard dev-panel tidak sinkron
   dengan stat card "Total Member Premium".

   Penyebab: dev_installs_timeseries() menghitung garis "Premium Aktif" dari
   jumlah lisensi_request yang di-approve PADA hari tersebut (event harian),
   bukan jumlah toko yang statusnya premium aktif PADA hari tersebut
   (snapshot). Dua definisi berbeda ini bikin grafik kelihatan nggak nyambung
   sama angka "Total Member Premium" di atasnya, yang dihitung dari
   dev_dashboard_stats() sebagai snapshot toko.plan='premium' saat ini.

   Perbaikan: hitung "premium_aktif" dari langganan_log — jumlah toko unik
   yang punya periode langganan (mulai..selesai) yang mencakup tanggal
   tersebut. Ini konsisten dengan cara dev_dashboard_stats() menghitung toko
   premium aktif (toko.expired_at selalu di-update mengikuti langganan_log
   terbaru tiap kali dev_approve_lisensi/aktivasi_premium jalan).

   Aman dijalankan berulang.
   ════════════════════════════════════════════════════════════════════════════ */

CREATE OR REPLACE FUNCTION dev_installs_timeseries(p_days int DEFAULT 14)
RETURNS TABLE(tanggal date, aplikasi_baru bigint, premium_aktif bigint)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  WITH hari AS (
    SELECT generate_series(CURRENT_DATE - (p_days - 1), CURRENT_DATE, interval '1 day')::date AS tanggal
  )
  SELECT
    h.tanggal,
    COALESCE((SELECT COUNT(*) FROM toko t WHERE t.created_at::date = h.tanggal), 0),
    COALESCE((SELECT COUNT(DISTINCT l.id_toko) FROM langganan_log l
              WHERE l.mulai <= h.tanggal AND l.selesai >= h.tanggal), 0)
  FROM hari h
  ORDER BY h.tanggal;
END;
$$;

GRANT EXECUTE ON FUNCTION dev_installs_timeseries(int) TO anon;
