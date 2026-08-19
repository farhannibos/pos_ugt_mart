// ── STATE ─────────────────────────────────────────────────────────────────────
let _devUser = JSON.parse(localStorage.getItem('dev_user') || 'null');
let _chart = null;
let _tokoCache = [];
let _lisensiCache = [];
let _laporanCache = [];

const rupiah = (n) => 'Rp' + Number(n || 0).toLocaleString('id-ID');
const tanggal = (d) => d ? new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
const waktuRelatif = (d) => {
    if (!d) return '—';
    const diff = Math.floor((Date.now() - new Date(d).getTime()) / 1000);
    if (diff < 60) return 'baru saja';
    if (diff < 3600) return Math.floor(diff / 60) + ' menit lalu';
    if (diff < 86400) return Math.floor(diff / 3600) + ' jam lalu';
    if (diff < 86400 * 7) return Math.floor(diff / 86400) + ' hari lalu';
    return tanggal(d);
};
const escapeHtml = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function showToast(type, msg) {
    const wrap = document.getElementById('toast-wrap');
    const el = document.createElement('div');
    el.className = 'toast ' + type;
    el.innerHTML = `<i data-lucide="${type === 'success' ? 'check-circle-2' : 'alert-circle'}" style="width:16px;height:16px;color:${type === 'success' ? 'var(--primary)' : 'var(--danger)'}"></i><span>${escapeHtml(msg)}</span>`;
    wrap.appendChild(el);
    lucide.createIcons();
    setTimeout(() => el.remove(), 3800);
}

function openModal(id) { document.getElementById(id).classList.add('show'); lucide.createIcons(); }
function closeModal(id) { document.getElementById(id).classList.remove('show'); }

// ── AUTH ──────────────────────────────────────────────────────────────────────
async function doLogin() {
    const user = document.getElementById('login-user').value.trim();
    const pass = document.getElementById('login-pass').value;
    const errEl = document.getElementById('login-err');
    const btn = document.getElementById('login-btn');
    errEl.style.display = 'none';

    if (!user || !pass) {
        errEl.textContent = 'Username dan password wajib diisi';
        errEl.style.display = 'block';
        return;
    }

    btn.disabled = true;
    btn.textContent = 'Memproses...';
    try {
        const res = await devValidateLogin(user, pass);
        if (!res) {
            errEl.textContent = 'Username atau password salah';
            errEl.style.display = 'block';
        } else {
            _devUser = res;
            localStorage.setItem('dev_user', JSON.stringify(res));
            enterApp();
        }
    } catch (e) {
        errEl.textContent = 'Gagal terhubung ke server: ' + e.message;
        errEl.style.display = 'block';
    }
    btn.disabled = false;
    btn.textContent = 'Masuk';
}

function doLogout() {
    localStorage.removeItem('dev_user');
    _devUser = null;
    document.getElementById('app').style.display = 'none';
    document.getElementById('login-screen').style.display = 'flex';
    document.getElementById('login-user').value = '';
    document.getElementById('login-pass').value = '';
}

function enterApp() {
    document.getElementById('login-screen').style.display = 'none';
    document.getElementById('app').style.display = 'block';
    document.getElementById('dev-nama').textContent = _devUser.nama;
    document.getElementById('dev-avatar').textContent = (_devUser.nama || '?').charAt(0).toUpperCase();
    lucide.createIcons();
    loadDashboard();
}

// ── NAVIGATION ────────────────────────────────────────────────────────────────
function navigate(page, el, label) {
    document.querySelectorAll('.nav-item').forEach((n) => n.classList.remove('active'));
    if (el) el.classList.add('active');
    document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
    document.getElementById('page-' + page).classList.add('active');
    document.getElementById('breadcrumb-label').textContent = label;

    if (page === 'dashboard') loadDashboard();
    else if (page === 'aplikasi') loadAplikasi();
    else if (page === 'transaksi') loadTransaksi();
    else if (page === 'laporan') loadLaporan();
    else if (page === 'user-management') loadLisensi();
    else if (page === 'pengaturan') loadPengaturan();
}

function refreshCurrentPage() {
    const active = document.querySelector('.page.active');
    if (!active) return;
    const icon = document.getElementById('refresh-icon');
    icon.classList.add('spin');
    const page = active.id.replace('page-', '');
    const map = { dashboard: loadDashboard, aplikasi: loadAplikasi, transaksi: loadTransaksi, laporan: loadLaporan, 'user-management': loadLisensi, pengaturan: loadPengaturan };
    Promise.resolve((map[page] || (() => {}))()).finally(() => icon.classList.remove('spin'));
}

function toggleDarkMode() {
    document.body.classList.toggle('dark');
    const isDark = document.body.classList.contains('dark');
    localStorage.setItem('dev_dark', isDark ? '1' : '0');
    document.getElementById('dark-icon').setAttribute('data-lucide', isDark ? 'sun' : 'moon');
    lucide.createIcons();
    if (_chart) renderChart(_chart._raw || []);
}

// ── DASHBOARD ─────────────────────────────────────────────────────────────────
async function loadDashboard() {
    try {
        const stats = await devDashboardStats();
        document.getElementById('st-total-aplikasi').textContent = stats.total_aplikasi ?? 0;
        document.getElementById('st-free').textContent = stats.total_free ?? 0;
        document.getElementById('st-premium').textContent = stats.total_premium ?? 0;
        document.getElementById('st-hari-ini').textContent = stats.terinstal_hari_ini ?? 0;
        document.getElementById('st-pengajuan').textContent = stats.pengajuan_bulan_ini ?? 0;
    } catch (e) { showToast('error', 'Gagal memuat statistik: ' + e.message); }

    try {
        const series = await devInstallsTimeseries(14);
        renderChart(series);
    } catch (e) { console.error(e); }

    try {
        const activity = await devRecentActivity(12);
        renderActivity(activity);
    } catch (e) {
        document.getElementById('activity-list').innerHTML = '<div class="empty-state">Gagal memuat aktivitas</div>';
    }
}

function renderChart(series) {
    const ctx = document.getElementById('dev-chart');
    if (!ctx) return;
    const isDark = document.body.classList.contains('dark');
    const gridColor = isDark ? '#334155' : '#E2E8F0';
    const textColor = isDark ? '#94A3B8' : '#64748B';
    const labels = series.map((s) => new Date(s.tanggal).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' }));

    if (_chart) _chart.destroy();
    _chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels,
            datasets: [
                { label: 'Aplikasi Baru', data: series.map((s) => s.aplikasi_baru), borderColor: '#16A34A', backgroundColor: '#16A34A22', fill: true, tension: 0.35, pointRadius: 2 },
                { label: 'Premium Aktif', data: series.map((s) => s.premium_aktif), borderColor: '#8B5CF6', backgroundColor: '#8B5CF622', fill: true, tension: 0.35, pointRadius: 2 },
            ],
        },
        options: {
            responsive: true,
            plugins: { legend: { labels: { color: textColor, font: { size: 11 } } } },
            scales: {
                x: { ticks: { color: textColor, font: { size: 10 } }, grid: { color: gridColor } },
                y: { beginAtZero: true, ticks: { color: textColor, font: { size: 10 }, precision: 0 }, grid: { color: gridColor } },
            },
        },
    });
    _chart._raw = series;
}

function renderActivity(list) {
    const el = document.getElementById('activity-list');
    if (!list.length) { el.innerHTML = '<div class="empty-state">Belum ada aktivitas</div>'; return; }
    const iconFor = (jenis) => ({ toko_baru: 'smartphone', lisensi_pending: 'file-clock', lisensi_approved: 'check-circle-2', lisensi_declined: 'x-circle' }[jenis] || 'activity');
    el.innerHTML = list.map((a) => `
        <div class="activity-item">
            <div class="activity-dot"><i data-lucide="${iconFor(a.jenis)}"></i></div>
            <div>
                <div class="activity-title">${escapeHtml(a.judul)}</div>
                <div class="activity-sub">${escapeHtml(a.keterangan)}</div>
            </div>
            <div class="activity-time">${waktuRelatif(a.waktu)}</div>
        </div>`).join('');
    lucide.createIcons();
}

// ── APLIKASI ──────────────────────────────────────────────────────────────────
async function loadAplikasi() {
    try {
        _tokoCache = await devListToko();
        renderAplikasi();
    } catch (e) { showToast('error', 'Gagal memuat daftar aplikasi: ' + e.message); }
}

function renderAplikasi() {
    const tbody = document.getElementById('aplikasi-tbody');
    const q = (document.getElementById('ap-search')?.value || '').toLowerCase();
    const rows = _tokoCache.filter((r) => (r.nama_toko || '').toLowerCase().includes(q));

    if (!rows.length) { tbody.innerHTML = '<tr><td colspan="7"><div class="empty-state">Tidak ada data</div></td></tr>'; return; }

    tbody.innerHTML = rows.map((r) => {
        const isPremium = r.plan === 'premium';
        const exp = r.expired_at ? new Date(r.expired_at) : null;
        const diff = exp ? Math.floor((exp - new Date()) / 86400000) : null;
        let statusHtml = '<span class="badge badge-gray">Free</span>';
        if (isPremium) {
            if (diff !== null && diff < 0) statusHtml = '<span class="badge badge-red">Expired</span>';
            else if (diff !== null && diff <= 7) statusHtml = `<span class="badge badge-yellow">Exp ${diff}h lagi</span>`;
            else statusHtml = '<span class="badge badge-green">Aktif</span>';
        }
        return `<tr>
            <td><strong>${escapeHtml(r.nama_toko)}</strong></td>
            <td>${escapeHtml(r.owner_nama || '—')}</td>
            <td>${escapeHtml(r.no_hp || '—')}</td>
            <td><span class="badge ${isPremium ? 'badge-purple' : 'badge-gray'}">${isPremium ? 'Premium' : 'Free'}</span></td>
            <td>${tanggal(r.expired_at)}</td>
            <td>${statusHtml}</td>
            <td>
                <button class="btn btn-sm btn-primary" onclick="openModalAktivasi('${r.id_toko}','${escapeHtml(r.nama_toko).replace(/'/g, "\\'")}')"><i data-lucide="badge-check"></i>Aktifkan</button>
                <button class="btn btn-sm btn-danger" onclick="confirmHapusToko('${r.id_toko}','${escapeHtml(r.nama_toko).replace(/'/g, "\\'")}')"><i data-lucide="trash-2"></i></button>
            </td>
        </tr>`;
    }).join('');
    lucide.createIcons();
}

function openModalAktivasi(idToko, namaToko) {
    document.getElementById('akt-id-toko').value = idToko;
    document.getElementById('akt-nama-toko').value = namaToko;
    document.getElementById('akt-bulan').value = 1;
    document.getElementById('akt-nominal').value = '';
    document.getElementById('akt-keterangan').value = '';
    document.getElementById('akt-err').style.display = 'none';
    openModal('modal-aktivasi');
}

async function doAktivasiPremium() {
    const idToko = parseInt(document.getElementById('akt-id-toko').value);
    const bulan = parseInt(document.getElementById('akt-bulan').value) || 1;
    const nominal = parseInt(document.getElementById('akt-nominal').value) || 0;
    const keterangan = document.getElementById('akt-keterangan').value.trim();
    const errEl = document.getElementById('akt-err');
    const btn = document.getElementById('akt-btn');

    if (!nominal) { errEl.textContent = 'Isi nominal pembayaran'; errEl.style.display = 'block'; return; }

    btn.disabled = true; btn.textContent = 'Memproses...';
    try {
        const res = await devAktivasiPremium(idToko, bulan, nominal, keterangan || `Aktivasi ${bulan} bulan`, _devUser.nama);
        if (res?.ok) {
            closeModal('modal-aktivasi');
            showToast('success', 'Premium berhasil diaktifkan');
            loadAplikasi();
        } else {
            errEl.textContent = res?.pesan || 'Gagal mengaktifkan premium';
            errEl.style.display = 'block';
        }
    } catch (e) {
        errEl.textContent = e.message; errEl.style.display = 'block';
    }
    btn.disabled = false;
    btn.innerHTML = '<i data-lucide="badge-check"></i>Aktifkan Premium';
    lucide.createIcons();
}

function confirmHapusToko(idToko, namaToko) {
    if (!confirm(`Hapus toko "${namaToko}" beserta seluruh datanya secara permanen?`)) return;
    devHapusToko(parseInt(idToko))
        .then((res) => { showToast('success', `Toko "${res.nama_toko || namaToko}" dihapus`); loadAplikasi(); })
        .catch((e) => showToast('error', 'Gagal menghapus: ' + e.message));
}

// ── TRANSAKSI ─────────────────────────────────────────────────────────────────
async function loadTransaksi() {
    const endEl = document.getElementById('tr-start');
    if (!endEl.value) {
        const end = new Date(); const start = new Date(); start.setDate(start.getDate() - 30);
        document.getElementById('tr-start').value = start.toISOString().slice(0, 10);
        document.getElementById('tr-end').value = end.toISOString().slice(0, 10);
    }
    const start = document.getElementById('tr-start').value;
    const end = document.getElementById('tr-end').value;

    try {
        const rows = await devLaporanPendapatan(start, end);
        const tbody = document.getElementById('transaksi-tbody');
        if (!rows.length) { tbody.innerHTML = '<tr><td colspan="6"><div class="empty-state">Tidak ada transaksi</div></td></tr>'; }
        else {
            tbody.innerHTML = rows.map((r) => `<tr>
                <td>${tanggal(r.created_at)}</td>
                <td><strong>${escapeHtml(r.nama_toko)}</strong></td>
                <td>${tanggal(r.mulai)} — ${tanggal(r.selesai)}</td>
                <td>${rupiah(r.nominal)}</td>
                <td>${escapeHtml(r.keterangan || '—')}</td>
                <td>${escapeHtml(r.created_by || '—')}</td>
            </tr>`).join('');
        }
        document.getElementById('tr-jumlah').textContent = rows.length;
        document.getElementById('tr-total').textContent = rupiah(rows.reduce((a, r) => a + (r.nominal || 0), 0));
        const bulanIni = rows.filter((r) => new Date(r.created_at).getMonth() === new Date().getMonth() && new Date(r.created_at).getFullYear() === new Date().getFullYear());
        document.getElementById('tr-bulan-ini').textContent = rupiah(bulanIni.reduce((a, r) => a + (r.nominal || 0), 0));
    } catch (e) { showToast('error', 'Gagal memuat transaksi: ' + e.message); }
}

// ── LAPORAN ───────────────────────────────────────────────────────────────────
async function loadLaporan() {
    if (!document.getElementById('lap-start').value) {
        const end = new Date(); const start = new Date(); start.setDate(1);
        document.getElementById('lap-start').value = start.toISOString().slice(0, 10);
        document.getElementById('lap-end').value = end.toISOString().slice(0, 10);
    }
    const start = document.getElementById('lap-start').value;
    const end = document.getElementById('lap-end').value;

    try {
        const rows = await devLaporanPendapatan(start, end);
        _laporanCache = rows;
        const total = rows.reduce((a, r) => a + (r.nominal || 0), 0);
        document.getElementById('lap-total').textContent = rupiah(total);
        document.getElementById('lap-jumlah').textContent = rows.length;

        const byToko = {};
        rows.forEach((r) => {
            byToko[r.nama_toko] = byToko[r.nama_toko] || { jumlah: 0, nominal: 0 };
            byToko[r.nama_toko].jumlah++;
            byToko[r.nama_toko].nominal += (r.nominal || 0);
        });
        const sorted = Object.entries(byToko).sort((a, b) => b[1].nominal - a[1].nominal);
        document.getElementById('lap-top-toko').textContent = sorted[0]?.[0] || '—';

        const tbody = document.getElementById('laporan-tbody');
        tbody.innerHTML = sorted.length
            ? sorted.map(([nama, v]) => `<tr><td><strong>${escapeHtml(nama)}</strong></td><td>${v.jumlah}</td><td>${rupiah(v.nominal)}</td></tr>`).join('')
            : '<tr><td colspan="3"><div class="empty-state">Tidak ada data pada periode ini</div></td></tr>';
    } catch (e) { showToast('error', 'Gagal memuat laporan: ' + e.message); }
}

function exportLaporanCsv() {
    if (!_laporanCache.length) { showToast('error', 'Tidak ada data untuk diexport'); return; }
    const header = ['Tanggal', 'Toko', 'Mulai', 'Selesai', 'Nominal', 'Keterangan', 'Oleh'];
    const rows = _laporanCache.map((r) => [r.created_at, r.nama_toko, r.mulai, r.selesai, r.nominal, r.keterangan, r.created_by]);
    const csv = [header, ...rows].map((row) => row.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `laporan-pendapatan-${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(a); a.click(); a.remove();
    URL.revokeObjectURL(url);
}

// ── USER MANAGEMENT (lisensi_request) ────────────────────────────────────────
async function loadLisensi() {
    try {
        _lisensiCache = await devListLisensiRequests();
        renderLisensi();
        document.getElementById('lr-pending').textContent = _lisensiCache.filter((r) => r.status === 'pending').length;
        document.getElementById('lr-approved').textContent = _lisensiCache.filter((r) => r.status === 'approved').length;
        document.getElementById('lr-declined').textContent = _lisensiCache.filter((r) => r.status === 'declined').length;
    } catch (e) { showToast('error', 'Gagal memuat pengajuan: ' + e.message); }

    if (!_tokoCache.length) {
        try { _tokoCache = await devListToko(); } catch (e) { /* noop */ }
    }
}

function renderLisensi() {
    const tbody = document.getElementById('lisensi-tbody');
    const q = (document.getElementById('lr-search')?.value || '').toLowerCase();
    const rows = _lisensiCache.filter((r) =>
        (r.no_invoice || '').toLowerCase().includes(q) ||
        (r.id_device || '').toLowerCase().includes(q) ||
        (r.nama_toko || '').toLowerCase().includes(q));

    if (!rows.length) { tbody.innerHTML = '<tr><td colspan="8"><div class="empty-state">Belum ada pengajuan</div></td></tr>'; return; }

    const statusBadge = { pending: '<span class="badge badge-yellow">Pending</span>', approved: '<span class="badge badge-green">Approved</span>', declined: '<span class="badge badge-red">Declined</span>' };

    tbody.innerHTML = rows.map((r) => `<tr>
        <td class="mono">${escapeHtml(r.no_invoice)}</td>
        <td class="mono">${escapeHtml(r.id_device)}</td>
        <td><strong>${escapeHtml(r.nama_toko)}</strong><br><span class="text-dim" style="font-size:11px">${escapeHtml(r.owner_nama || '—')}</span></td>
        <td>${r.durasi_bulan} bln</td>
        <td>${rupiah(r.harga)}</td>
        <td>${statusBadge[r.status] || r.status}</td>
        <td>${tanggal(r.diajukan_at)}</td>
        <td>${r.status === 'pending' ? `
            <button class="btn btn-sm btn-primary" onclick="approveLisensi(${r.id})"><i data-lucide="check"></i></button>
            <button class="btn btn-sm btn-danger" onclick="openModalTolak(${r.id})"><i data-lucide="x"></i></button>
        ` : `<span class="text-dim" style="font-size:11.5px">oleh ${escapeHtml(r.diproses_oleh || '—')}</span>`}</td>
    </tr>`).join('');
    lucide.createIcons();
}

function openModalAjukan() {
    const sel = document.getElementById('ajukan-id-toko');
    sel.innerHTML = '<option value="">-- Pilih Member/Toko --</option>' + _tokoCache.map((t) => `<option value="${t.id_toko}">${escapeHtml(t.nama_toko)}</option>`).join('');
    document.getElementById('ajukan-id-device').value = '';
    document.getElementById('ajukan-durasi').value = 1;
    document.getElementById('ajukan-harga').value = '';
    document.getElementById('ajukan-catatan').value = '';
    document.getElementById('ajukan-err').style.display = 'none';
    openModal('modal-ajukan');
}

async function submitAjukanLisensi() {
    const idToko = parseInt(document.getElementById('ajukan-id-toko').value);
    const idDevice = document.getElementById('ajukan-id-device').value.trim();
    const durasi = parseInt(document.getElementById('ajukan-durasi').value) || 1;
    const harga = parseInt(document.getElementById('ajukan-harga').value) || 0;
    const catatan = document.getElementById('ajukan-catatan').value.trim();
    const errEl = document.getElementById('ajukan-err');
    const btn = document.getElementById('ajukan-btn');

    if (!idToko) { errEl.textContent = 'Pilih member/toko terlebih dahulu'; errEl.style.display = 'block'; return; }
    if (!idDevice) { errEl.textContent = 'ID Device wajib diisi'; errEl.style.display = 'block'; return; }

    btn.disabled = true; btn.textContent = 'Memproses...';
    try {
        const res = await devAjukanLisensi(idToko, idDevice, durasi, harga, catatan);
        if (res?.ok) {
            closeModal('modal-ajukan');
            showToast('success', `Pengajuan dibuat (${res.no_invoice})`);
            loadLisensi();
        } else {
            errEl.textContent = res?.pesan || 'Gagal membuat pengajuan';
            errEl.style.display = 'block';
        }
    } catch (e) { errEl.textContent = e.message; errEl.style.display = 'block'; }
    btn.disabled = false;
    btn.innerHTML = '<i data-lucide="send"></i>Ajukan';
    lucide.createIcons();
}

async function approveLisensi(id) {
    if (!confirm('Setujui pengajuan ini? Toko akan langsung diaktifkan ke premium.')) return;
    try {
        const res = await devApproveLisensi(id, _devUser.nama);
        if (res?.ok) { showToast('success', res.pesan || 'Pengajuan disetujui'); loadLisensi(); }
        else showToast('error', res?.pesan || 'Gagal menyetujui pengajuan');
    } catch (e) { showToast('error', e.message); }
}

let _tolakId = null;
function openModalTolak(id) {
    _tolakId = id;
    document.getElementById('tolak-alasan').value = '';
    openModal('modal-tolak');
}
async function submitTolakLisensi() {
    if (!_tolakId) return;
    const alasan = document.getElementById('tolak-alasan').value.trim();
    try {
        const res = await devDeclineLisensi(_tolakId, _devUser.nama, alasan);
        closeModal('modal-tolak');
        if (res?.ok) { showToast('success', 'Pengajuan ditolak'); loadLisensi(); }
        else showToast('error', res?.pesan || 'Gagal menolak pengajuan');
    } catch (e) { showToast('error', e.message); }
}

// ── PENGATURAN ────────────────────────────────────────────────────────────────
async function loadPengaturan() {
    try {
        const users = await devListUsers();
        const tbody = document.getElementById('devuser-tbody');
        tbody.innerHTML = users.map((u) => `<tr>
            <td>${escapeHtml(u.username)}</td>
            <td>${escapeHtml(u.nama)}</td>
            <td>${u.aktif ? '<span class="badge badge-green">Aktif</span>' : '<span class="badge badge-gray">Nonaktif</span>'}</td>
            <td>${tanggal(u.created_at)}</td>
        </tr>`).join('');
    } catch (e) { showToast('error', 'Gagal memuat akun developer: ' + e.message); }
}

async function submitChangePassword() {
    const oldPass = document.getElementById('pw-old').value;
    const newPass = document.getElementById('pw-new').value;
    const confirmPass = document.getElementById('pw-confirm').value;
    if (!oldPass || !newPass) { showToast('error', 'Lengkapi semua field password'); return; }
    if (newPass !== confirmPass) { showToast('error', 'Konfirmasi password tidak cocok'); return; }
    try {
        const res = await devChangePassword(_devUser.username, oldPass, newPass);
        if (res?.ok) {
            showToast('success', 'Password berhasil diubah');
            document.getElementById('pw-old').value = '';
            document.getElementById('pw-new').value = '';
            document.getElementById('pw-confirm').value = '';
        } else showToast('error', res?.pesan || 'Gagal mengubah password');
    } catch (e) { showToast('error', e.message); }
}

function openModalAddDev() {
    document.getElementById('dev-nama-baru').value = '';
    document.getElementById('dev-username-baru').value = '';
    document.getElementById('dev-password-baru').value = '';
    document.getElementById('dev-err').style.display = 'none';
    openModal('modal-add-dev');
}
async function submitAddDev() {
    const nama = document.getElementById('dev-nama-baru').value.trim();
    const username = document.getElementById('dev-username-baru').value.trim();
    const password = document.getElementById('dev-password-baru').value;
    const errEl = document.getElementById('dev-err');
    if (!nama || !username || !password) { errEl.textContent = 'Semua field wajib diisi'; errEl.style.display = 'block'; return; }
    try {
        const res = await devCreateUser(username, password, nama);
        if (res?.ok) { closeModal('modal-add-dev'); showToast('success', 'Akun developer dibuat'); loadPengaturan(); }
        else { errEl.textContent = res?.pesan || 'Gagal membuat akun'; errEl.style.display = 'block'; }
    } catch (e) { errEl.textContent = e.message; errEl.style.display = 'block'; }
}

// ── INIT ──────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    lucide.createIcons();
    document.getElementById('topbar-date').textContent = new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

    if (localStorage.getItem('dev_dark') === '1') {
        document.body.classList.add('dark');
        document.getElementById('dark-icon')?.setAttribute('data-lucide', 'sun');
    }

    ['login-user', 'login-pass'].forEach((id) => {
        document.getElementById(id).addEventListener('keydown', (e) => { if (e.key === 'Enter') doLogin(); });
    });

    if (_devUser) enterApp();
    lucide.createIcons();
});
