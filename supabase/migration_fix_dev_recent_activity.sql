/* ════════════════════════════════════════════════════════════════════════════
   FIX — dev_recent_activity mengembalikan error 400:
   "invalid UNION/INTERSECT/EXCEPT ORDER BY clause"
   Penyebab: ORDER BY di luar UNION ALL dari dua subquery yang masing-masing
   sudah punya ORDER BY+LIMIT sendiri tidak valid di Postgres. Perbaikannya:
   bungkus UNION ALL sebagai subquery di FROM, baru ORDER BY di query terluar.
   Aman dijalankan berulang.
   ════════════════════════════════════════════════════════════════════════════ */

CREATE OR REPLACE FUNCTION dev_recent_activity(p_limit int DEFAULT 15)
RETURNS TABLE(jenis text, judul text, keterangan text, waktu timestamptz)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT combined.jenis, combined.judul, combined.keterangan, combined.waktu
  FROM (
    (
      SELECT 'toko_baru'::text AS jenis, t.nama_toko AS judul,
             'Aplikasi baru terinstal'::text AS keterangan, t.created_at AS waktu
      FROM toko t
      ORDER BY t.created_at DESC
      LIMIT p_limit
    )
    UNION ALL
    (
      SELECT
        'lisensi_' || r.status AS jenis,
        t.nama_toko AS judul,
        CASE r.status
          WHEN 'pending'  THEN 'Mengajukan premium (' || r.no_invoice || ')'
          WHEN 'approved' THEN 'Premium disetujui (' || r.no_invoice || ')'
          ELSE 'Pengajuan ditolak (' || r.no_invoice || ')'
        END AS keterangan,
        COALESCE(r.diproses_at, r.diajukan_at) AS waktu
      FROM lisensi_request r
      JOIN toko t ON t.id = r.id_toko
      ORDER BY COALESCE(r.diproses_at, r.diajukan_at) DESC
      LIMIT p_limit
    )
  ) combined
  ORDER BY combined.waktu DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION dev_recent_activity(int) TO anon;
