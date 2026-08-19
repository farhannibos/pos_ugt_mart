// Sama persis dengan project Supabase yang dipakai pos_ugt_mart & web-panel,
// supaya dev-panel membaca data toko/langganan yang sama (real, bukan mock).
const SUPABASE_URL = 'https://oxktbostinewjosnnlvb.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im94a3Rib3N0aW5ld2pvc25ubHZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzMTM0NTgsImV4cCI6MjEwMDg4OTQ1OH0.hgHckyCEFzYw40syW0Dg_AlTfmM8NuZ7HbN1987xv4c';

const _sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

// ── AUTH (dev_users, terpisah dari akun toko) ────────────────────────────────
async function devValidateLogin(username, password) {
    const { data, error } = await _sb.rpc('dev_validate_login', {
        p_username: username,
        p_password: password,
    });
    if (error || !data || data.length === 0) return null;
    return data[0]; // { id, nama, username }
}

async function devChangePassword(username, oldPass, newPass) {
    const { data, error } = await _sb.rpc('dev_change_password', {
        p_username: username, p_old_password: oldPass, p_new_password: newPass,
    });
    if (error) throw error;
    return data;
}

async function devCreateUser(username, password, nama) {
    const { data, error } = await _sb.rpc('dev_create_user', {
        p_username: username, p_password: password, p_nama: nama,
    });
    if (error) throw error;
    return data;
}

async function devListUsers() {
    const { data, error } = await _sb.rpc('dev_list_users');
    if (error) throw error;
    return data || [];
}

// ── DASHBOARD ─────────────────────────────────────────────────────────────────
async function devDashboardStats() {
    const { data, error } = await _sb.rpc('dev_dashboard_stats');
    if (error) throw error;
    return data || {};
}

async function devInstallsTimeseries(days = 14) {
    const { data, error } = await _sb.rpc('dev_installs_timeseries', { p_days: days });
    if (error) throw error;
    return data || [];
}

async function devRecentActivity(limit = 15) {
    const { data, error } = await _sb.rpc('dev_recent_activity', { p_limit: limit });
    if (error) throw error;
    return data || [];
}

// ── APLIKASI (toko) ──────────────────────────────────────────────────────────
async function devListToko() {
    const { data, error } = await _sb.rpc('list_toko_langganan');
    if (error) throw error;
    return data || [];
}

async function devAktivasiPremium(idToko, bulan, nominal, keterangan, admin) {
    const { data, error } = await _sb.rpc('aktivasi_premium', {
        p_id_toko: idToko, p_bulan: bulan, p_nominal: nominal,
        p_keterangan: keterangan, p_admin: admin,
    });
    if (error) throw error;
    return Array.isArray(data) ? data[0] : data;
}

async function devHapusToko(idToko) {
    const { data, error } = await _sb.rpc('delete_toko_complete', { p_id_toko: idToko });
    if (error) throw error;
    return data;
}

// ── USER MANAGEMENT (lisensi_request) ────────────────────────────────────────
async function devListLisensiRequests() {
    const { data, error } = await _sb.rpc('dev_list_lisensi_requests');
    if (error) throw error;
    return data || [];
}

async function devAjukanLisensi(idToko, idDevice, durasiBulan, harga, catatan) {
    const { data, error } = await _sb.rpc('dev_ajukan_lisensi', {
        p_id_toko: idToko, p_id_device: idDevice, p_durasi_bulan: durasiBulan,
        p_harga: harga, p_catatan: catatan,
    });
    if (error) throw error;
    return data;
}

async function devApproveLisensi(idRequest, admin) {
    const { data, error } = await _sb.rpc('dev_approve_lisensi', {
        p_id_request: idRequest, p_admin: admin,
    });
    if (error) throw error;
    return data;
}

async function devDeclineLisensi(idRequest, admin, alasan) {
    const { data, error } = await _sb.rpc('dev_decline_lisensi', {
        p_id_request: idRequest, p_admin: admin, p_alasan: alasan,
    });
    if (error) throw error;
    return data;
}

// ── LAPORAN ───────────────────────────────────────────────────────────────────
async function devLaporanPendapatan(start, end) {
    const { data, error } = await _sb.rpc('dev_laporan_pendapatan', {
        p_start: start, p_end: end,
    });
    if (error) throw error;
    return data || [];
}
