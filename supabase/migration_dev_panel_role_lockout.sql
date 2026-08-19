    /* ════════════════════════════════════════════════════════════════════════════
      MIGRASI — DEV PANEL: ROLE (admin/staff), NONAKTIFKAN AKUN, LOGIN LOCKOUT
      Jalankan SETELAH migration_dev_panel.sql.
      Aman dijalankan berulang (semua statement idempotent).

      Efek migrasi ini:
      - Semua akun dev_users yang SUDAH ADA otomatis jadi role 'admin' (tidak ada
        yang ke-lockout aksesnya). Akun baru lewat form "Tambah Admin" defaultnya
        'staff' kecuali admin yang bikin memilih role lain.
      - Staf biasa tetap bisa lihat semua halaman & "Ajukan Baru" lisensi, tapi
        TIDAK bisa: Aktifkan Premium Langsung, Hapus Toko, Approve/Decline
        lisensi, Tambah/Nonaktifkan akun developer lain — itu semua khusus admin.
      ════════════════════════════════════════════════════════════════════════════ */

    -- 1. Kolom baru di dev_users
    ALTER TABLE dev_users ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'admin' CHECK (role IN ('admin','staff'));
    ALTER TABLE dev_users ADD COLUMN IF NOT EXISTS failed_attempts int NOT NULL DEFAULT 0;
    ALTER TABLE dev_users ADD COLUMN IF NOT EXISTS locked_until timestamptz;

    -- 2. Helper internal: pastikan pemanggil adalah admin aktif.
    --    Sengaja TIDAK di-GRANT ke anon — hanya dipanggil dari dalam fungsi
    --    SECURITY DEFINER lain di file ini, tidak bisa dipanggil langsung dari client.
    CREATE OR REPLACE FUNCTION _dev_require_admin(p_username text)
    RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    DECLARE
      v_nama  text;
      v_role  text;
      v_aktif boolean;
    BEGIN
      SELECT nama, role, aktif INTO v_nama, v_role, v_aktif
      FROM dev_users WHERE username = p_username;

      IF NOT FOUND OR NOT v_aktif THEN
        RAISE EXCEPTION 'Akun tidak ditemukan atau nonaktif';
      END IF;
      IF v_role <> 'admin' THEN
        RAISE EXCEPTION 'Aksi ini khusus untuk admin';
      END IF;
      RETURN v_nama;
    END;
    $$;

    -- 3. dev_create_user: tambah p_role + verifikasi admin (kalau dipanggil dari UI)
    DROP FUNCTION IF EXISTS dev_create_user(text, text, text);
    CREATE OR REPLACE FUNCTION dev_create_user(
      p_username    text,
      p_password    text,
      p_nama        text,
      p_role        text DEFAULT 'staff',
      p_by_username text DEFAULT NULL
    ) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    BEGIN
      -- p_by_username NULL = dipanggil manual dari SQL Editor (bootstrap akun pertama), lewati cek admin.
      IF p_by_username IS NOT NULL THEN
        PERFORM _dev_require_admin(p_by_username);
      END IF;

      IF p_role NOT IN ('admin','staff') THEN
        RETURN jsonb_build_object('ok', false, 'pesan', 'Role tidak valid');
      END IF;

      IF EXISTS (SELECT 1 FROM dev_users WHERE username = p_username) THEN
        RETURN jsonb_build_object('ok', false, 'pesan', 'Username sudah digunakan');
      END IF;

      INSERT INTO dev_users (username, password_hash, nama, role)
      VALUES (p_username, crypt(p_password, gen_salt('bf')), p_nama, p_role);

      RETURN jsonb_build_object('ok', true, 'pesan', 'Akun developer berhasil dibuat');
    END;
    $$;

    -- 4. dev_validate_login: tambah role di hasil + lockout brute-force
    --    (5x salah berturut-turut -> terkunci 15 menit)
    --    DROP dulu karena Postgres tidak izinkan CREATE OR REPLACE mengubah
    --    kolom RETURNS TABLE dari fungsi yang sudah ada.
    DROP FUNCTION IF EXISTS dev_validate_login(text, text);
    CREATE OR REPLACE FUNCTION dev_validate_login(p_username text, p_password text)
    RETURNS TABLE(id bigint, nama text, username text, role text)
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    DECLARE
      v_user dev_users%ROWTYPE;
    BEGIN
      SELECT * INTO v_user FROM dev_users u WHERE u.username = p_username;

      IF NOT FOUND OR NOT v_user.aktif THEN
        RETURN;
      END IF;

      IF v_user.locked_until IS NOT NULL AND v_user.locked_until > now() THEN
        RAISE EXCEPTION 'Akun terkunci sementara karena terlalu banyak percobaan gagal. Coba lagi setelah %.',
          to_char(v_user.locked_until, 'HH24:MI');
      END IF;

      IF v_user.password_hash = crypt(p_password, v_user.password_hash) THEN
        UPDATE dev_users u SET failed_attempts = 0, locked_until = NULL WHERE u.id = v_user.id;
        RETURN QUERY SELECT v_user.id, v_user.nama, v_user.username, v_user.role;
      ELSE
        UPDATE dev_users u
        SET failed_attempts = u.failed_attempts + 1,
            locked_until = CASE WHEN u.failed_attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE u.locked_until END
        WHERE u.id = v_user.id;
        RETURN;
      END IF;
    END;
    $$;

    -- 5. dev_list_users: tambah kolom role
    DROP FUNCTION IF EXISTS dev_list_users();
    CREATE OR REPLACE FUNCTION dev_list_users()
    RETURNS TABLE(id bigint, username text, nama text, role text, aktif boolean, created_at timestamptz)
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    BEGIN
      RETURN QUERY SELECT u.id, u.username, u.nama, u.role, u.aktif, u.created_at
      FROM dev_users u ORDER BY u.created_at ASC;
    END;
    $$;

    -- 6. Aktif/nonaktifkan akun developer — khusus admin, tidak bisa nonaktifkan diri sendiri
    CREATE OR REPLACE FUNCTION dev_set_user_aktif(p_id bigint, p_aktif boolean, p_by_username text)
    RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    DECLARE
      v_target_username text;
    BEGIN
      PERFORM _dev_require_admin(p_by_username);

      SELECT username INTO v_target_username FROM dev_users WHERE id = p_id;
      IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'pesan', 'Akun tidak ditemukan');
      END IF;
      IF v_target_username = p_by_username AND NOT p_aktif THEN
        RETURN jsonb_build_object('ok', false, 'pesan', 'Tidak bisa menonaktifkan akun sendiri');
      END IF;

      UPDATE dev_users SET aktif = p_aktif WHERE id = p_id;
      RETURN jsonb_build_object('ok', true,
        'pesan', CASE WHEN p_aktif THEN 'Akun diaktifkan' ELSE 'Akun dinonaktifkan' END);
    END;
    $$;

    -- 7. dev_approve_lisensi / dev_decline_lisensi — khusus admin.
    --    Ganti p_admin (nama bebas dari client) jadi p_by_username (diverifikasi server).
    DROP FUNCTION IF EXISTS dev_approve_lisensi(bigint, text);
    CREATE OR REPLACE FUNCTION dev_approve_lisensi(
      p_id_request  bigint,
      p_by_username text DEFAULT NULL
    ) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    DECLARE
      v_admin_nama      text;
      v_req             lisensi_request%ROWTYPE;
      v_mulai           date := CURRENT_DATE;
      v_selesai         date;
      v_current_expired date;
      v_current_plan    text;
      v_log_id          bigint;
    BEGIN
      v_admin_nama := _dev_require_admin(p_by_username);

      SELECT * INTO v_req FROM lisensi_request WHERE id = p_id_request;
      IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'pesan', 'Pengajuan tidak ditemukan');
      END IF;
      IF v_req.status <> 'pending' THEN
        RETURN jsonb_build_object('ok', false, 'pesan', 'Pengajuan sudah diproses sebelumnya');
      END IF;

      SELECT plan, expired_at INTO v_current_plan, v_current_expired
      FROM toko WHERE id = v_req.id_toko;

      IF v_current_plan = 'premium' AND v_current_expired IS NOT NULL AND v_current_expired >= CURRENT_DATE THEN
        v_mulai := v_current_expired + 1;
      END IF;
      v_selesai := v_mulai + (v_req.durasi_bulan * 30) - 1;

      UPDATE toko SET plan = 'premium', expired_at = v_selesai WHERE id = v_req.id_toko;

      INSERT INTO langganan_log (id_toko, mulai, selesai, nominal, keterangan, created_by)
      VALUES (v_req.id_toko, v_mulai, v_selesai,
              v_req.harga,
              'Approve pengajuan ' || v_req.no_invoice || ' (device: ' || v_req.id_device || ')',
              v_admin_nama)
      RETURNING id INTO v_log_id;

      UPDATE lisensi_request
      SET status = 'approved', diproses_at = now(), diproses_oleh = v_admin_nama, id_langganan_log = v_log_id
      WHERE id = p_id_request;

      RETURN jsonb_build_object('ok', true, 'selesai', v_selesai::text,
        'pesan', 'Premium diaktifkan sampai ' || to_char(v_selesai, 'DD Mon YYYY'));
    END;
    $$;

    DROP FUNCTION IF EXISTS dev_decline_lisensi(bigint, text, text);
    CREATE OR REPLACE FUNCTION dev_decline_lisensi(
      p_id_request  bigint,
      p_by_username text DEFAULT NULL,
      p_alasan      text DEFAULT NULL
    ) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    DECLARE
      v_admin_nama text;
      v_status     text;
    BEGIN
      v_admin_nama := _dev_require_admin(p_by_username);

      SELECT status INTO v_status FROM lisensi_request WHERE id = p_id_request;
      IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'pesan', 'Pengajuan tidak ditemukan');
      END IF;
      IF v_status <> 'pending' THEN
        RETURN jsonb_build_object('ok', false, 'pesan', 'Pengajuan sudah diproses sebelumnya');
      END IF;

      UPDATE lisensi_request
      SET status = 'declined', diproses_at = now(), diproses_oleh = v_admin_nama,
          catatan = CASE WHEN p_alasan IS NULL OR trim(p_alasan) = '' THEN catatan
                          ELSE COALESCE(catatan || ' | ', '') || 'Ditolak: ' || p_alasan END
      WHERE id = p_id_request;

      RETURN jsonb_build_object('ok', true, 'pesan', 'Pengajuan ditolak');
    END;
    $$;

    -- 8. Wrapper admin-only untuk aktivasi premium & hapus toko.
    --    Fungsi asli (aktivasi_premium, delete_toko_complete) TIDAK diubah karena
    --    didefinisikan di luar file migrasi yang terlacak di repo ini — wrapper ini
    --    cuma menambah lapisan cek admin sebelum memanggilnya.
    CREATE OR REPLACE FUNCTION dev_aktivasi_premium_checked(
      p_id_toko     bigint,
      p_bulan       int,
      p_nominal     integer,
      p_keterangan  text,
      p_by_username text
    ) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    DECLARE
      v_admin_nama text;
    BEGIN
      v_admin_nama := _dev_require_admin(p_by_username);
      RETURN aktivasi_premium(
        p_id_toko => p_id_toko, p_bulan => p_bulan, p_nominal => p_nominal,
        p_keterangan => p_keterangan, p_admin => v_admin_nama
      );
    END;
    $$;

    CREATE OR REPLACE FUNCTION dev_hapus_toko_checked(p_id_toko bigint, p_by_username text)
    RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER AS $$
    BEGIN
      PERFORM _dev_require_admin(p_by_username);
      RETURN delete_toko_complete(p_id_toko => p_id_toko);
    END;
    $$;

    -- 9. Grants
    GRANT EXECUTE ON FUNCTION dev_create_user(text, text, text, text, text)   TO anon;
    GRANT EXECUTE ON FUNCTION dev_validate_login(text, text)                 TO anon;
    GRANT EXECUTE ON FUNCTION dev_list_users()                               TO anon;
    GRANT EXECUTE ON FUNCTION dev_set_user_aktif(bigint, boolean, text)       TO anon;
    GRANT EXECUTE ON FUNCTION dev_approve_lisensi(bigint, text)               TO anon;
    GRANT EXECUTE ON FUNCTION dev_decline_lisensi(bigint, text, text)         TO anon;
    GRANT EXECUTE ON FUNCTION dev_aktivasi_premium_checked(bigint,int,integer,text,text) TO anon;
    GRANT EXECUTE ON FUNCTION dev_hapus_toko_checked(bigint, text)            TO anon;
