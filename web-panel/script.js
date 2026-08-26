/* ═══════════════════════════════════════════════════
   POS FABIZO — Admin Panel Script
   ═══════════════════════════════════════════════════ */

lucide.createIcons();

// ── DATA ARRAYS (in-memory, persisted to localStorage) ─────────────
let DATA_KATEGORI = [
    { id: 'KT-001', nama: 'Sembako', deskripsi: 'Kebutuhan pokok sehari-hari', status: 'Aktif' },
    { id: 'KT-002', nama: 'Minuman', deskripsi: 'Berbagai jenis minuman kemasan', status: 'Aktif' },
    { id: 'KT-003', nama: 'Snack & Makanan Ringan', deskripsi: 'Camilan dan makanan ringan', status: 'Aktif' },
    { id: 'KT-004', nama: 'Toiletries', deskripsi: 'Produk perawatan diri', status: 'Aktif' },
    { id: 'KT-005', nama: 'Kebersihan', deskripsi: 'Produk kebersihan rumah', status: 'Aktif' },
    { id: 'KT-006', nama: 'Bumbu Masak', deskripsi: 'Aneka bumbu dan rempah', status: 'Aktif' },
    { id: 'KT-007', nama: 'Produk Beku', deskripsi: 'Makanan beku dan frozen food', status: 'Non-aktif' },
];

let DATA_BARANG    = [];
let DATA_SUPPLIER  = [];
let DATA_MEMBER    = [];
let DATA_PENJUALAN = [];

let DATA_USERS = []; // populated from profiles table via dbLoadAll()

// ── QR LOGIN ─────────────────────────────────────────────────────
let _qrToken     = null;
let _qrPollTimer = null;
let _qrExpTimer  = null;
let _qrSeconds   = 300; // 5 menit

async function switchLoginTab(tab) {
    const isQr = tab === 'qr';
    document.getElementById('tab-password').classList.toggle('active', !isQr);
    document.getElementById('tab-qr').classList.toggle('active', isQr);
    document.getElementById('login-panel-password').style.display = isQr ? 'none' : '';
    document.getElementById('login-panel-qr').style.display = isQr ? '' : 'none';
    if (isQr) {
        await startQrSession();
    } else {
        stopQrSession();
    }
}

async function startQrSession() {
    stopQrSession();
    document.getElementById('qr-status').textContent = 'Membuat QR Code...';
    document.getElementById('qr-overlay').style.display = 'none';

    try {
        _qrToken = await dbGenerateQrToken();
    } catch (e) {
        console.error('startQrSession:', e);
        _qrToken = null;
    }
    if (!_qrToken) {
        document.getElementById('qr-status').textContent = 'Gagal membuat QR. Coba lagi.';
        return;
    }

    // Render QR code ke div (qrcodejs)
    const qrEl = document.getElementById('qr-canvas');
    qrEl.innerHTML = '';
    new QRCode(qrEl, {
        text: 'ugtmart-qr:' + _qrToken,
        width: 180, height: 180,
        colorDark: '#0F172A', colorLight: '#ffffff',
        correctLevel: QRCode.CorrectLevel.M,
    });

    document.getElementById('qr-status').textContent = 'Menunggu scan dari aplikasi mobile...';

    // Hitung mundur 5 menit
    _qrSeconds = 300;
    _qrExpTimer = setInterval(() => {
        _qrSeconds--;
        const m = Math.floor(_qrSeconds / 60);
        const s = _qrSeconds % 60;
        const timerEl = document.getElementById('qr-timer');
        if (timerEl) timerEl.textContent = `QR berlaku ${m}:${s.toString().padStart(2, '0')}`;
        if (_qrSeconds <= 0) refreshQR();
    }, 1000);

    // Polling tiap 2 detik
    _qrPollTimer = setInterval(async () => {
        const result = await dbCheckQrStatus(_qrToken);
        if (!result) return;

        if (result.status === 'expired') {
            document.getElementById('qr-status').textContent = 'QR sudah expired. Klik Perbarui QR.';
            stopQrSession();
            return;
        }

        if (result.status === 'scanned') {
            stopQrSession();
            // Tampilkan overlay centang
            document.getElementById('qr-overlay').style.display = 'flex';
            document.getElementById('qr-status').textContent = 'Berhasil! Sedang masuk...';

            // Login dengan data dari QR
            setTimeout(async () => {
                const found = {
                    username:    result.username,
                    nama:        result.nama,
                    role:        result.role,
                    avatar:      result.nama[0].toUpperCase(),
                    avatarColor: result.avatar_color ?? '#16A34A',
                };
                // Set scope toko sebelum load data
                if (result.id_toko) {
                    setCurrentToko(result.id_toko);
                    localStorage.setItem('ugt_id_toko', result.id_toko.toString());
                }
                localStorage.setItem('ugt_logged', '1');
                localStorage.setItem('ugt_user', JSON.stringify(found));
                try { await dbLoadAll(); } catch {}
                try { await dbLoadAllExtra(); } catch {}
                showApp(found);
            }, 1000);
        }
    }, 2000);
}

function stopQrSession() {
    clearInterval(_qrPollTimer);
    clearInterval(_qrExpTimer);
    _qrPollTimer = null;
    _qrExpTimer  = null;
}

async function refreshQR() {
    await startQrSession();
}

// ── LOGIN & SESSION ──────────────────────────────────────────────
async function doLogin() {
    const u = document.getElementById('login-user').value.trim();
    const p = document.getElementById('login-pass').value.trim();
    const errEl = document.getElementById('login-err');

    const dbUser = await dbValidateLogin(u, p);
    if (!dbUser) {
        errEl.textContent = 'Username atau password salah.';
        errEl.style.display = 'block';
        document.getElementById('login-pass').value = '';
        document.getElementById('login-pass').focus();
        return;
    }

    if (dbUser.role === 'Kasir') {
        errEl.textContent = 'Role Kasir hanya untuk aplikasi mobile. Silakan gunakan aplikasi POS.';
        errEl.style.display = 'block';
        document.getElementById('login-pass').value = '';
        document.getElementById('login-pass').focus();
        return;
    }

    const found = {
        username:    u,
        nama:        dbUser.nama,
        role:        dbUser.role,
        avatar:      dbUser.nama[0].toUpperCase(),
        avatarColor: dbUser.avatar_color ?? '#16A34A',
    };

    // Set scope toko sebelum load data
    setCurrentToko(dbUser.id_toko);
    localStorage.setItem('ugt_id_toko', dbUser.id_toko?.toString() ?? '');

    errEl.style.display = 'none';
    localStorage.setItem('ugt_logged', '1');
    localStorage.setItem('ugt_user', JSON.stringify(found));

    // Muat data toko ini sebelum tampilkan app
    try { await dbLoadAll(); } catch {}
    try {
        const hasil = await dbLoadAllExtra();
        if (hasil.gagal.length) console.info('Tabel belum dimigrasi (v2.1):', hasil.gagal.join(', '));
    } catch {}

    showApp(found);
}

function showApp(user) {
    stopQrSession(); // hentikan polling kalau masih jalan
    if (!user) {
        const raw = localStorage.getItem('ugt_user');
        user = raw ? JSON.parse(raw) : null;
    }
    document.querySelector('.u-name').textContent = user.nama;
    document.querySelector('.u-role').textContent = user.role;
    document.querySelector('.user-avatar').textContent = user.avatar;
    document.querySelector('.user-avatar').style.background = `linear-gradient(135deg, ${user.avatarColor}, ${user.avatarColor}cc)`;

    applyRoleAccess(user.role);

    const loginEl = document.getElementById('login-screen');
    loginEl.style.opacity = '0';
    loginEl.style.transition = 'opacity 0.4s ease';
    setTimeout(() => {
        loginEl.style.display = 'none';
        if (window._loginBgFrameId) { cancelAnimationFrame(window._loginBgFrameId); window._loginBgFrameId = 0; }
    }, 400);

    setupRealtime();
    initPageData();
    setTimeout(() => { initCharts(); }, 100);
    lucide.createIcons();
    showToast('success', 'Selamat datang, ' + user.nama + '!');
}

async function refreshAllData() {
    const btn = document.getElementById('btn-refresh');
    if (btn) {
        btn.disabled = true;
        btn.style.opacity = '0.5';
        btn.style.animation = 'spin 1s linear infinite';
    }
    try {
        await dbLoadAll();
        try { await dbLoadAllExtra(); } catch {}
        if (typeof initPageData === 'function') initPageData();
        if (typeof initCharts === 'function') setTimeout(initCharts, 100);
        showToast('success', 'Data berhasil diperbarui');
    } catch (e) {
        showToast('error', 'Gagal memperbarui data: ' + e.message);
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.style.opacity = '';
            btn.style.animation = '';
        }
    }
}

function doLogout() {
    showConfirm('Konfirmasi Keluar', 'Apakah Anda yakin ingin keluar dari sistem?', async () => {
        teardownRealtime();
        await dbSignOut();
        setCurrentToko(null);
        localStorage.removeItem('ugt_logged');
        localStorage.removeItem('ugt_user');
        localStorage.removeItem('ugt_id_toko');
        // Reset semua array data agar data toko lama tidak tersisa
        DATA_BARANG.length = 0; DATA_MEMBER.length = 0; DATA_PENJUALAN.length = 0;
        DATA_KATEGORI.length = 0; DATA_USERS.length = 0; DATA_SUPPLIER.length = 0;
        DATA_CABANG.length = 0; DATA_RESELLER.length = 0; DATA_PEMBELIAN.length = 0;
        DATA_RETUR_BELI.length = 0; DATA_RETUR_JUAL.length = 0; DATA_KAS.length = 0;
        DATA_OPNAME.length = 0; DATA_ADJ.length = 0; DATA_PEMBAYARAN.length = 0;
        DATA_STOK_LOG.length = 0; DATA_SHIFT_LIST.length = 0; DATA_SHIFT_AKTIF = null;
        const loginEl = document.getElementById('login-screen');
        loginEl.style.display = 'flex';
        loginEl.style.opacity = '0';
        setTimeout(() => { loginEl.style.opacity = '1'; loginEl.style.transition = 'opacity 0.4s ease'; }, 10);
        document.getElementById('login-pass').value = '';
        showToast('info', 'Anda telah keluar dari sistem.');
    }, { type: 'warning', icon: 'log-out', btnText: 'Ya, Keluar' });
}

// ── ROLE-BASED ACCESS ────────────────────────────────────────────
// Daftar halaman per peran. Sebelumnya hanya menyembunyikan `.admin-only`,
// sehingga Admin masih bisa membuka semua halaman kecuali users & pengaturan.
const AKSES_PERAN = {
    'Owner': null, // null = akses penuh
    'Admin': [
        'dashboard',
        'kategori', 'barang', 'supplier',
        'member', 'cabang', 'reseller',
        'pembelian', 'retur-beli', 'penjualan', 'retur-jual',
        'piutang', 'hutang', 'kas-kasir', 'stock-opname', 'adj-stok',
        'lap-penjualan', 'lap-pembelian', 'lap-piutang', 'lap-hutang',
        'lap-kas', 'lap-stok', 'lap-log-stok',
        'shift-kasir',
    ],
    // Kasir: mobile only — diblokir saat login web panel
};

function halamanDiizinkan(role) {
    return AKSES_PERAN[role] ?? null;
}

function bolehAkses(pageId, role) {
    const izin = halamanDiizinkan(role || userSekarang().role);
    return izin === null || izin.includes(pageId);
}

function applyRoleAccess(role) {
    const izin = halamanDiizinkan(role);

    if (izin === null) {
        // Owner: pastikan semua terlihat lagi (misal setelah ganti user).
        document.querySelectorAll('.owner-only').forEach(el => el.style.display = '');
        document.querySelectorAll('[data-page]').forEach(el => el.style.display = '');
    } else {
        document.querySelectorAll('.owner-only').forEach(el => el.style.display = 'none');
        document.querySelectorAll('[data-page]').forEach(el => {
            el.style.display = izin.includes(el.getAttribute('data-page')) ? '' : 'none';
        });
    }

    // Sembunyikan grup menu yang seluruh isinya tidak boleh diakses.
    ['sub-master', 'sub-pelanggan', 'sub-trx', 'sub-lap'].forEach(subId => {
        const sub = document.getElementById(subId);
        if (!sub) return;
        const adaYangTampil = [...sub.querySelectorAll('[data-page]')].some(i => i.style.display !== 'none');
        sub.style.display = adaYangTampil ? '' : 'none';
        const induk = sub.previousElementSibling;
        if (induk && (induk.classList.contains('nav-item') || induk.classList.contains('nav-sub-item'))) {
            induk.style.display = adaYangTampil ? '' : 'none';
        }
    });

    // Kalau halaman yang sedang terbuka tidak diizinkan, lempar ke dashboard.
    const aktif = document.querySelector('.page.active');
    if (aktif && izin !== null) {
        const pageId = aktif.id.replace('page-', '');
        if (!izin.includes(pageId)) navigate('dashboard', document.querySelector('[data-page="dashboard"]'), 'Dashboard');
    }
}

// ── INITIALIZE ALL PAGE DATA ──────────────────────────────────────
function initPageData() {
    renderKategori();
    renderBarang();
    renderSupplier();
    renderMember();
    renderPenjualan();
    renderUsers();
    // Modul v1.1 — halaman yang sebelumnya statis
    renderCabang();
    renderReseller();
    renderPembelian();
    renderReturBeli();
    renderReturJual();
    renderPiutang();
    renderHutang();
    renderKas();
    renderOpname();
    renderAdj();
    renderStokLog();
    renderShiftKasir();
    renderShiftBadge();
    // Laporan
    renderLaporanStok();
    renderLaporanPenjualan();
    renderLaporanPiutang();
    renderLaporanPembelian();
    renderLaporanHutang();
    renderLaporanKas();
    updateDashboard();
    populateKategoriSelect();
    populateSupplierSelects();
    populateLapStokKategori();
    populateLapPembelianSupplier();
    populateKasirSelects();
    muatPengaturan();
    lucide.createIcons();
}

// ── DASHBOARD ────────────────────────────────────────────────────
async function updateDashboard() {
    const now      = new Date();
    const curMonth = now.getMonth();
    const curYear  = now.getFullYear();
    const prevMonth = curMonth === 0 ? 11 : curMonth - 1;
    const prevYear  = curMonth === 0 ? curYear - 1 : curYear;

    const filterBulan = (arr, key, m, y) =>
        arr.filter(r => { const d = new Date(r[key]); return d.getMonth() === m && d.getFullYear() === y; });

    const trendHtml = (cur, prev) => {
        if (prev === 0) return '<span style="color:var(--text-3)">bulan ini</span>';
        const pct = ((cur - prev) / prev * 100).toFixed(1);
        const naik = cur >= prev;
        const icon = naik ? 'trending-up' : 'trending-down';
        const cls  = naik ? 'trend-up' : 'trend-down';
        return `<i data-lucide="${icon}" style="width:12px;height:12px"></i> ${naik ? '+' : ''}${pct}% vs bulan lalu`;
    };

    const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    const setHtml = (id, val) => { const el = document.getElementById(id); if (el) el.innerHTML = val; };

    // ── Penjualan bulan ini vs bulan lalu
    const pjIni  = filterBulan(DATA_PENJUALAN, 'tanggal', curMonth, curYear).reduce((s, t) => s + t.total, 0);
    const pjLalu = filterBulan(DATA_PENJUALAN, 'tanggal', prevMonth, prevYear).reduce((s, t) => s + t.total, 0);
    setEl('dash-penjualan', formatRp(pjIni));
    const trendPj = document.getElementById('dash-trend-penjualan');
    if (trendPj) {
        trendPj.className = 'stat-trend ' + (pjIni >= pjLalu ? 'trend-up' : 'trend-down');
        trendPj.innerHTML = trendHtml(pjIni, pjLalu);
    }

    // ── Pembelian bulan ini vs bulan lalu
    const pbIni  = filterBulan(DATA_PEMBELIAN, 'tanggal', curMonth, curYear).reduce((s, p) => s + p.total, 0);
    const pbLalu = filterBulan(DATA_PEMBELIAN, 'tanggal', prevMonth, prevYear).reduce((s, p) => s + p.total, 0);
    setEl('dash-pembelian', formatRp(pbIni));
    const trendPb = document.getElementById('dash-trend-pembelian');
    if (trendPb) {
        trendPb.className = 'stat-trend ' + (pbIni >= pbLalu ? 'trend-up' : 'trend-down');
        trendPb.innerHTML = trendHtml(pbIni, pbLalu);
    }

    // ── Piutang aktif (belum lunas)
    const piutangAktif = DATA_PENJUALAN.filter(t => t.status === 'Piutang');
    const totalPiutang = piutangAktif.reduce((s, t) => s + (t.total - (t.terbayar || 0)), 0);
    setEl('dash-piutang', formatRp(totalPiutang));
    setEl('dash-piutang-count', `${piutangAktif.length} tagihan aktif`);

    // ── Hutang aktif (belum lunas)
    const hutangAktif = DATA_PEMBELIAN.filter(p => p.status === 'Hutang');
    const totalHutang = hutangAktif.reduce((s, p) => s + (p.total - (p.terbayar || 0)), 0);
    setEl('dash-hutang', formatRp(totalHutang));

    // ── Kas Aktif (saldo shift kasir yang sedang berjalan, bukan all-time)
    if (DATA_SHIFT_AKTIF) {
        const saldoAktif = await dbShiftSaldo(DATA_SHIFT_AKTIF.id);
        setEl('dash-kas', saldoAktif != null ? formatRp(saldoAktif) : '—');
        setEl('dash-kas-sub', `Shift berjalan: ${DATA_SHIFT_AKTIF.kasirNama || '—'}`);
    } else {
        setEl('dash-kas', '—');
        setEl('dash-kas-sub', 'Tidak ada shift aktif');
    }

    // ── Rincian Kas Kasir (breakdown formula, lihat rincianKasKasir())
    const cardRincianKas = document.getElementById('card-rincian-kas');
    if (DATA_SHIFT_AKTIF) {
        const r = rincianKasKasir(DATA_SHIFT_AKTIF);
        setEl('rk-omzet', formatRp(r.omzet));
        setEl('rk-kas-terakhir', formatRp(r.kasTerakhir));
        setEl('rk-kas-masuk', '+ ' + formatRp(r.kasMasuk));
        setEl('rk-piutang', '− ' + formatRp(r.piutang));
        setEl('rk-nontunai', '− ' + formatRp(r.nontunai));
        setEl('rk-kas-keluar', '− ' + formatRp(r.kasKeluarLain));
        setEl('rk-pembelian', '− ' + formatRp(r.pembelianTunai));
        setEl('rk-total', formatRp(r.total));
        if (cardRincianKas) cardRincianKas.style.display = '';
    } else if (cardRincianKas) {
        cardRincianKas.style.display = 'none';
    }

    // ── Supplier aktif
    const supAktif  = DATA_SUPPLIER.filter(s => s.status === 'Aktif').length;
    setEl('dash-supplier-aktif', supAktif);

    // ── Transaksi terbaru (5 data)
    const tbl = document.querySelector('#tbl-dash-trx tbody');
    if (tbl) {
        tbl.innerHTML = DATA_PENJUALAN.slice(0, 5).map(t => `
            <tr>
                <td><code class="inv-code">#${escapeHtml(t.id)}</code></td>
                <td>${escapeHtml(t.pelanggan)}</td>
                <td>${formatRp(t.total)}</td>
                <td><span class="badge ${badgeStatus(t.status)}">${escapeHtml(t.status)}</span></td>
            </tr>`).join('');
    }

    // ── Barang favorit (paling banyak terjual)
    const terjualPerBarang = {};
    for (const t of DATA_PENJUALAN) {
        for (const it of (t.items || [])) {
            if (!it.nama) continue;
            terjualPerBarang[it.nama] = (terjualPerBarang[it.nama] || 0) + (it.qty || 0);
        }
    }
    const barangFavorit = Object.entries(terjualPerBarang).sort((a, b) => b[1] - a[1]).slice(0, 5);
    const tblBrgFav = document.querySelector('#tbl-dash-barang-favorit tbody');
    if (tblBrgFav) {
        tblBrgFav.innerHTML = barangFavorit.length
            ? barangFavorit.map(([nama, qty]) => `<tr><td>${escapeHtml(nama)}</td><td>${qty}</td></tr>`).join('')
            : tableEmptyHTML(2, 'Belum ada penjualan', 'Data akan muncul setelah ada transaksi');
    }

    // ── Stok hampir habis
    const lowStock = DATA_BARANG.filter(b => b.stok <= b.stokMin && b.status === 'Aktif').slice(0, 5);
    const tbl2 = document.querySelector('#tbl-dash-stok tbody');
    if (tbl2) {
        tbl2.innerHTML = lowStock.length
            ? lowStock.map(b => `<tr><td>${escapeHtml(b.nama)}</td><td><span class="badge ${b.stok === 0 ? 'badge-red' : 'badge-yellow'}">${b.stok}</span></td><td>${b.stokMin}</td></tr>`).join('')
            : '<tr><td colspan="3" style="text-align:center;color:var(--text-3);padding:20px">Semua stok aman</td></tr>';
    }

    lucide.createIcons();
}

function refreshDashboard() {
    updateDashboard();
    showToast('success', 'Dashboard berhasil diperbarui!');
}

// ── KATEGORI CRUD ─────────────────────────────────────────────────
let editKategoriIdx = -1;

function renderKategori() {
    const tbody = document.querySelector('#tbl-kategori tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_KATEGORI.length
        ? DATA_KATEGORI.map((k, i) => `
        <tr>
            <td>${escapeHtml(k.kode || k.id)}</td>
            <td><strong>${escapeHtml(k.nama)}</strong></td>
            <td>${escapeHtml(k.deskripsi) || '—'}</td>
            <td>${DATA_BARANG.filter(b => b.kategori === k.nama).length}</td>
            <td><span class="badge ${k.status === 'Aktif' ? 'badge-green' : 'badge-yellow'}">${escapeHtml(k.status)}</span></td>
            <td><div class="td-actions">
                <button class="btn btn-info btn-sm" onclick="bukaEditKategori(${i})" aria-label="Edit ${escapeHtml(k.nama)}" title="Edit"><i data-lucide="pencil"></i></button>
                <button class="btn btn-danger btn-sm" onclick="hapusKategori(${i})" aria-label="Hapus ${escapeHtml(k.nama)}" title="Hapus"><i data-lucide="trash-2"></i></button>
            </div></td>
        </tr>`).join('')
        : tableEmptyHTML(6, 'Belum ada kategori', 'Klik Tambah Kategori untuk memulai');
    document.getElementById('info-kategori').textContent = `Menampilkan ${DATA_KATEGORI.length} data`;
    lucide.createIcons();
}

function openTambahKategori() {
    editKategoriIdx = -1;
    document.getElementById('modal-kategori-title').textContent = 'Tambah Kategori';
    document.getElementById('form-kategori').reset();
    document.getElementById('fk-kode').value = 'KT-' + Date.now();
    document.getElementById('fk-status').value = 'Aktif';
    openModal('modal-kategori');
}

function bukaEditKategori(idx) {
    editKategoriIdx = idx;
    const k = DATA_KATEGORI[idx];
    document.getElementById('modal-kategori-title').textContent = 'Edit Kategori';
    document.getElementById('fk-kode').value = k.kode || k.id;
    document.getElementById('fk-nama').value = k.nama;
    document.getElementById('fk-deskripsi').value = k.deskripsi;
    document.getElementById('fk-status').value = k.status;
    openModal('modal-kategori');
}

async function simpanKategori() {
    const nama = document.getElementById('fk-nama').value.trim();
    if (!nama) { showToast('error', 'Nama kategori wajib diisi!'); return; }

    const isEdit = editKategoriIdx >= 0;
    const data = {
        id:    isEdit ? DATA_KATEGORI[editKategoriIdx].id : null,
        kode:  document.getElementById('fk-kode').value.trim(),
        nama,
        deskripsi: document.getElementById('fk-deskripsi').value.trim(),
        status: document.getElementById('fk-status').value,
    };

    let savedId;
    try {
        savedId = await dbUpsertKategori(data);
    } catch (e) {
        showToast('error', e.message || 'Gagal menyimpan kategori ke database!');
        console.error('simpanKategori error:', e);
        return;
    }
    if (savedId === null) {
        showToast('error', 'Gagal menyimpan kategori ke database!');
        return;
    }
    data.id = savedId;

    if (isEdit) {
        DATA_KATEGORI[editKategoriIdx] = data;
        showToast('success', 'Kategori berhasil diperbarui!');
    } else {
        DATA_KATEGORI.push(data);
        showToast('success', 'Kategori baru berhasil ditambahkan!');
    }

    closeModal('modal-kategori');
    renderKategori();
    populateKategoriSelect();
}

function hapusKategori(idx) {
    const k = DATA_KATEGORI[idx];
    const used = DATA_BARANG.filter(b => b.kategori === k.nama).length;
    if (used > 0) {
        showToast('error', `Kategori "${escapeHtml(k.nama)}" dipakai oleh ${used} barang. Hapus atau pindahkan barang terlebih dahulu.`);
        return;
    }
    showConfirm('Hapus Kategori', `Yakin ingin menghapus kategori "${escapeHtml(k.nama)}"?`, async () => {
        if (k.id && !isNaN(Number(k.id))) {
            const ok = await dbDeleteKategori(k.id);
            if (!ok) { showToast('error', 'Gagal menghapus kategori!'); return; }
        }
        DATA_KATEGORI.splice(idx, 1);
        renderKategori();
        populateKategoriSelect();
        showToast('success', 'Kategori berhasil dihapus.');
    });
}

// ── BARANG CRUD ───────────────────────────────────────────────────
let editBarangIdx = -1;
let filteredBarang = [];
let _fotoBarangFile = null;  // File object foto yang dipilih
let _fotoBarangHapus = false; // flag: user hapus foto existing

function previewFotoBarang(input) {
    const file = input.files[0];
    if (!file) return;
    if (file.size > 2 * 1024 * 1024) {
        showToast('error', 'Foto maksimal 2 MB!');
        input.value = '';
        return;
    }
    _fotoBarangFile = file;
    _fotoBarangHapus = false;
    const reader = new FileReader();
    reader.onload = e => {
        document.getElementById('fb-foto-img').src = e.target.result;
        document.getElementById('fb-foto-preview').style.display = 'block';
        document.getElementById('fb-foto-placeholder').style.display = 'none';
    };
    reader.readAsDataURL(file);
}

function hapusFotoBarang() {
    _fotoBarangFile = null;
    _fotoBarangHapus = true;
    document.getElementById('fb-foto-input').value = '';
    document.getElementById('fb-foto-img').src = '';
    document.getElementById('fb-foto-preview').style.display = 'none';
    document.getElementById('fb-foto-placeholder').style.display = 'flex';
}

function _resetFotoBarang() {
    _fotoBarangFile = null;
    _fotoBarangHapus = false;
    document.getElementById('fb-foto-input').value = '';
    document.getElementById('fb-foto-img').src = '';
    document.getElementById('fb-foto-preview').style.display = 'none';
    document.getElementById('fb-foto-placeholder').style.display = 'flex';
}

function _tampilFotoBarang(url) {
    if (url) {
        document.getElementById('fb-foto-img').src = url;
        document.getElementById('fb-foto-preview').style.display = 'block';
        document.getElementById('fb-foto-placeholder').style.display = 'none';
    } else {
        _resetFotoBarang();
    }
}

function renderBarang(data) {
    data = data || DATA_BARANG;
    filteredBarang = data;
    const tbody = document.querySelector('#tbl-barang tbody');
    if (!tbody) return;
    tbody.innerHTML = data.length
        ? data.map((b, i) => {
            const realIdx = DATA_BARANG.indexOf(b);
            const stokBadge = b.stok === 0 ? 'badge-red' : (b.stok <= b.stokMin ? 'badge-yellow' : 'badge-green');
            const inisial = b.nama.trim().split(' ').slice(0,2).map(w=>w[0]||'').join('').toUpperCase() || '??';
            const fotoHtml = b.fotoUrl
                ? `<img src="${escapeHtml(b.fotoUrl)}" alt="${escapeHtml(b.nama)}" style="width:36px;height:36px;object-fit:cover;border-radius:8px;vertical-align:middle;margin-right:8px" onerror="this.style.display='none'">`
                : `<span style="display:inline-flex;align-items:center;justify-content:center;width:36px;height:36px;border-radius:8px;background:var(--primary-light);color:var(--primary);font-size:11px;font-weight:700;vertical-align:middle;margin-right:8px;flex-shrink:0">${inisial}</span>`;
            return `<tr>
                <td>${escapeHtml(b.kode || b.id)}</td>
                <td><div style="display:flex;align-items:center">${fotoHtml}<strong>${escapeHtml(b.nama)}</strong></div></td>
                <td>${escapeHtml(b.kategori)}</td>
                <td>${escapeHtml(b.satuan)}</td>
                <td>${formatRp(b.hargaBeli)}</td>
                <td>${formatRp(b.hargaJual)}</td>
                <td><span class="badge ${stokBadge}">${b.stok}</span></td>
                <td><span class="badge ${b.status === 'Aktif' ? 'badge-green' : 'badge-yellow'}">${escapeHtml(b.status)}</span></td>
                <td><div class="td-actions">
                    <button class="btn btn-info btn-sm" onclick="bukaEditBarang(${realIdx})" aria-label="Edit ${escapeHtml(b.nama)}" title="Edit"><i data-lucide="pencil"></i></button>
                    <button class="btn btn-danger btn-sm" onclick="hapusBarang(${realIdx})" aria-label="Hapus ${escapeHtml(b.nama)}" title="Hapus"><i data-lucide="trash-2"></i></button>
                </div></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(9, DATA_BARANG.length === 0 ? 'Belum ada barang' : 'Tidak ada hasil filter', DATA_BARANG.length === 0 ? 'Klik Tambah Barang untuk memulai' : 'Coba ubah filter atau kata kunci pencarian');
    document.getElementById('info-barang').textContent = `Menampilkan ${data.length} dari ${DATA_BARANG.length} data`;
    lucide.createIcons();
}

function openTambahBarang() {
    editBarangIdx = -1;
    document.getElementById('modal-barang-title').textContent = 'Tambah Barang';
    document.getElementById('form-barang').reset();
    document.getElementById('fb-kode').value = 'BRG-' + Date.now();
    document.getElementById('fb-stok').value = 0;
    document.getElementById('fb-stok-min').value = 10;
    document.getElementById('fb-status').value = 'Aktif';
    _resetFotoBarang();
    openModal('modal-barang');
}

function bukaEditBarang(idx) {
    editBarangIdx = idx;
    const b = DATA_BARANG[idx];
    document.getElementById('modal-barang-title').textContent = 'Edit Barang';
    document.getElementById('fb-kode').value = b.kode || b.id;
    document.getElementById('fb-nama').value = b.nama;
    document.getElementById('fb-kategori').value = b.kategori;
    document.getElementById('fb-satuan').value = b.satuan;
    document.getElementById('fb-harga-beli').value = b.hargaBeli;
    document.getElementById('fb-harga-jual').value = b.hargaJual;
    document.getElementById('fb-stok').value = b.stok;
    document.getElementById('fb-stok-min').value = b.stokMin;
    document.getElementById('fb-barcode').value = b.barcode || '';
    document.getElementById('fb-status').value = b.status;
    _tampilFotoBarang(b.fotoUrl || null);
    openModal('modal-barang');
}

async function simpanBarang() {
    const nama = document.getElementById('fb-nama').value.trim();
    const kategori = document.getElementById('fb-kategori').value;
    const hargaBeli = parseInt(document.getElementById('fb-harga-beli').value) || 0;
    const hargaJual = parseInt(document.getElementById('fb-harga-jual').value) || 0;

    if (!nama) { showToast('error', 'Nama barang wajib diisi!'); return; }
    if (!kategori) { showToast('error', 'Pilih kategori barang!'); return; }
    if (hargaJual <= 0) { showToast('error', 'Harga jual harus lebih dari 0!'); return; }
    if (hargaJual < hargaBeli) { showToast('warning', 'Harga jual lebih kecil dari harga beli!'); }

    const isEdit = editBarangIdx >= 0;
    const existing = isEdit ? DATA_BARANG[editBarangIdx] : null;

    // Upload foto jika ada file baru
    let fotoUrl = existing?.fotoUrl || null;
    if (_fotoBarangHapus) fotoUrl = null;
    if (_fotoBarangFile) {
        try {
            fotoUrl = await dbUploadFotoProduk(_fotoBarangFile, existing?.id || null);
        } catch(e) {
            showToast('warning', 'Foto gagal diupload, produk tetap disimpan tanpa foto');
            fotoUrl = existing?.fotoUrl || null;
        }
    }

    const data = {
        id:   isEdit ? existing.id : null,
        kode: document.getElementById('fb-kode').value.trim(),
        nama,
        kategori,
        satuan: document.getElementById('fb-satuan').value,
        hargaBeli,
        hargaJual,
        stok: parseInt(document.getElementById('fb-stok').value) || 0,
        stokMin: parseInt(document.getElementById('fb-stok-min').value) || 10,
        barcode: document.getElementById('fb-barcode').value.trim(),
        status: document.getElementById('fb-status').value,
        fotoUrl,
    };

    const savedId = await dbUpsertProduct(data);
    if (savedId) data.id = savedId;
    else showToast('warning', 'Tersimpan lokal, gagal sync ke server');

    if (isEdit) {
        DATA_BARANG[editBarangIdx] = data;
        showToast('success', 'Barang berhasil diperbarui!');
    } else {
        DATA_BARANG.push(data);
        showToast('success', 'Barang baru berhasil ditambahkan!');
    }

    closeModal('modal-barang');
    renderBarang();
    renderLaporanStok();
    updateDashboard();
}

function hapusBarang(idx) {
    const b = DATA_BARANG[idx];
    showConfirm('Hapus Barang', `Yakin ingin menghapus barang "${escapeHtml(b.nama)}"? Stok ${b.stok} unit akan hilang.`, async () => {
        if (b.id && !isNaN(Number(b.id))) await dbDeleteProduct(b.id);
        DATA_BARANG.splice(idx, 1);
        renderBarang();
        renderLaporanStok();
        updateDashboard();
        showToast('success', 'Barang berhasil dihapus.');
    });
}

function filterBarangKategori(kat) {
    const filtered = kat ? DATA_BARANG.filter(b => b.kategori === kat) : DATA_BARANG;
    renderBarang(filtered);
}

function filterBarangStatus(status) {
    const filtered = status ? DATA_BARANG.filter(b => b.status === status) : DATA_BARANG;
    renderBarang(filtered);
}

function populateKategoriSelect() {
    const sel = document.getElementById('fb-kategori');
    if (!sel) return;
    const current = sel.value;
    sel.innerHTML = '<option value="">Pilih Kategori</option>' +
        DATA_KATEGORI.filter(k => k.status === 'Aktif').map(k => `<option value="${escapeHtml(k.nama)}">${escapeHtml(k.nama)}</option>`).join('');
    if (current) sel.value = current;

    const filterSel = document.getElementById('filter-kategori-barang');
    if (filterSel) {
        filterSel.innerHTML = '<option value="">Semua Kategori</option>' +
            DATA_KATEGORI.map(k => `<option value="${escapeHtml(k.nama)}">${escapeHtml(k.nama)}</option>`).join('');
    }

    // Opname kategori select — dulu memakai selector `select:last-of-type`
    // yang justru mengenai dropdown petugas, jadi sekarang ditarget lewat id.
    const opSel = document.getElementById('fo-kategori');
    if (opSel) {
        const current = opSel.value;
        opSel.innerHTML = '<option value="">Semua Kategori</option>' +
            DATA_KATEGORI.map(k => `<option value="${escapeHtml(k.nama)}">${escapeHtml(k.nama)}</option>`).join('');
        if (current) opSel.value = current;
    }
}

// ── SUPPLIER CRUD ─────────────────────────────────────────────────
let editSupplierIdx = -1;

function renderSupplier() {
    const tbody = document.querySelector('#tbl-supplier tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_SUPPLIER.length
        ? DATA_SUPPLIER.map((s, i) => `
        <tr>
            <td>${escapeHtml(s.id)}</td>
            <td><strong>${escapeHtml(s.nama)}</strong></td>
            <td>${escapeHtml(s.kontak)}</td>
            <td>${escapeHtml(s.alamat)}</td>
            <td>${escapeHtml(s.email) || '—'}</td>
            <td><span class="badge ${s.status === 'Aktif' ? 'badge-green' : 'badge-yellow'}">${escapeHtml(s.status)}</span></td>
            <td><div class="td-actions">
                <button class="btn btn-info btn-sm" onclick="bukaEditSupplier(${i})" aria-label="Edit ${escapeHtml(s.nama)}" title="Edit"><i data-lucide="pencil"></i></button>
                <button class="btn btn-danger btn-sm" onclick="hapusSupplier(${i})" aria-label="Hapus ${escapeHtml(s.nama)}" title="Hapus"><i data-lucide="trash-2"></i></button>
            </div></td>
        </tr>`).join('')
        : tableEmptyHTML(7, 'Belum ada supplier', 'Klik Tambah Supplier untuk memulai');
    document.getElementById('info-supplier').textContent = `Menampilkan ${DATA_SUPPLIER.length} data`;
    lucide.createIcons();
}

function openTambahSupplier() {
    editSupplierIdx = -1;
    document.getElementById('modal-supplier-title').textContent = 'Tambah Supplier';
    document.getElementById('form-supplier').reset();
    document.getElementById('fs-kode').value = 'SUP-' + Date.now();
    document.getElementById('fs-status').value = 'Aktif';
    openModal('modal-supplier');
}

function bukaEditSupplier(idx) {
    editSupplierIdx = idx;
    const s = DATA_SUPPLIER[idx];
    document.getElementById('modal-supplier-title').textContent = 'Edit Supplier';
    document.getElementById('fs-kode').value = s.id;
    document.getElementById('fs-nama').value = s.nama;
    document.getElementById('fs-kontak').value = s.kontak;
    document.getElementById('fs-email').value = s.email || '';
    document.getElementById('fs-alamat').value = s.alamat;
    document.getElementById('fs-status').value = s.status;
    openModal('modal-supplier');
}

async function simpanSupplier() {
    const nama = document.getElementById('fs-nama').value.trim();
    const kontak = document.getElementById('fs-kontak').value.trim();
    if (!nama) { showToast('error', 'Nama supplier wajib diisi!'); return; }
    if (!kontak) { showToast('error', 'No. kontak wajib diisi!'); return; }

    const isEdit = editSupplierIdx >= 0;
    const data = {
        id: isEdit ? DATA_SUPPLIER[editSupplierIdx].id : null,
        nama,
        kontak,
        email: document.getElementById('fs-email').value.trim(),
        alamat: document.getElementById('fs-alamat').value.trim(),
        status: document.getElementById('fs-status').value,
    };

    // Sebelumnya supplier hanya disimpan di memori sehingga hilang saat refresh.
    const savedId = await dbUpsertSupplier(data);
    if (savedId) data.id = savedId;
    else { data.id = data.id || idLokal('SUP'); showToast('warning', 'Tersimpan lokal, gagal sync ke server.'); }

    if (isEdit) {
        const namaLama = DATA_SUPPLIER[editSupplierIdx].nama;
        DATA_SUPPLIER[editSupplierIdx] = data;
        // Rapikan referensi nama supplier di PO yang sudah ada.
        if (namaLama !== nama) {
            DATA_PEMBELIAN.forEach(p => { if (p.supplier === namaLama) p.supplier = nama; });
            DATA_RETUR_BELI.forEach(r => { if (r.supplier === namaLama) r.supplier = nama; });
        }
        showToast('success', 'Supplier berhasil diperbarui!');
    } else {
        DATA_SUPPLIER.push(data);
        showToast('success', 'Supplier baru berhasil ditambahkan!');
    }

    closeModal('modal-supplier');
    renderSupplier();
    renderPembelian();
    populateSupplierSelects();
    populateLapPembelianSupplier();
    updateDashboard();
}

function hapusSupplier(idx) {
    const s = DATA_SUPPLIER[idx];
    const hutangAktif = DATA_PEMBELIAN
        .filter(p => p.supplier === s.nama && p.status === 'Hutang')
        .reduce((sum, p) => sum + sisaTagihan(p), 0);
    if (hutangAktif > 0) {
        showToast('error', `Supplier "${escapeHtml(s.nama)}" masih punya hutang ${formatRp(hutangAktif)}. Lunasi dulu sebelum dihapus.`);
        return;
    }
    showConfirm('Hapus Supplier', `Yakin ingin menghapus supplier "${escapeHtml(s.nama)}"?`, async () => {
        const ok = await dbDeleteSupplier(s.id);
        if (!ok) { showToast('error', 'Gagal menghapus supplier dari database!'); return; }
        DATA_SUPPLIER.splice(idx, 1);
        renderSupplier();
        populateSupplierSelects();
        populateLapPembelianSupplier();
        showToast('success', 'Supplier berhasil dihapus.');
    });
}

function populateSupplierSelects() {
    // Dulu selectornya `#po-supplier, #modal-pembelian select`, sehingga SEMUA
    // dropdown di modal pembelian (barang, metode bayar) ikut ditimpa daftar
    // supplier. Sekarang hanya dropdown supplier yang diisi.
    const sel = document.getElementById('po-supplier');
    if (!sel) return;
    const current = sel.value;
    sel.innerHTML = '<option value="">Pilih Supplier</option>' +
        DATA_SUPPLIER.filter(s => s.status === 'Aktif')
            .map(s => `<option value="${escapeHtml(s.id)}">${escapeHtml(s.nama)}</option>`).join('');
    if (current) sel.value = current;
}

// ── MEMBER CRUD ───────────────────────────────────────────────────
let editMemberIdx = -1;

function renderMember() {
    const tbody = document.querySelector('#tbl-member tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_MEMBER.length
        ? DATA_MEMBER.map((m, i) => `
        <tr>
            <td>${escapeHtml(m.id)}</td>
            <td><strong>${escapeHtml(m.nama)}</strong></td>
            <td>${escapeHtml(m.hp)}</td>
            <td>${formatRp(m.totalBelanja)}</td>
            <td><span class="badge badge-purple">${m.poin.toLocaleString('id-ID')} poin</span></td>
            <td><span class="badge ${m.status === 'Aktif' ? 'badge-green' : 'badge-yellow'}">${escapeHtml(m.status)}</span></td>
            <td><div class="td-actions">
                <button class="btn btn-info btn-sm" onclick="bukaEditMember(${i})" aria-label="Edit ${escapeHtml(m.nama)}" title="Edit"><i data-lucide="pencil"></i></button>
                <button class="btn btn-danger btn-sm" onclick="hapusMember(${i})" aria-label="Hapus ${escapeHtml(m.nama)}" title="Hapus"><i data-lucide="trash-2"></i></button>
            </div></td>
        </tr>`).join('')
        : tableEmptyHTML(7, 'Belum ada member', 'Klik Tambah Member untuk memulai');
    document.getElementById('info-member').textContent = `Menampilkan ${DATA_MEMBER.length} data`;
    lucide.createIcons();
}

function openTambahMember() {
    editMemberIdx = -1;
    document.getElementById('modal-member-title').textContent = 'Tambah Member';
    document.getElementById('form-member').reset();
    document.getElementById('fm-kode').value = generateId('MBR', DATA_MEMBER);
    document.getElementById('fm-status').value = 'Aktif';
    openModal('modal-member');
}

function bukaEditMember(idx) {
    editMemberIdx = idx;
    const m = DATA_MEMBER[idx];
    document.getElementById('modal-member-title').textContent = 'Edit Member';
    document.getElementById('fm-kode').value = m.id;
    document.getElementById('fm-nama').value = m.nama;
    document.getElementById('fm-hp').value = m.hp;
    document.getElementById('fm-email').value = m.email || '';
    document.getElementById('fm-alamat').value = m.alamat || '';
    document.getElementById('fm-status').value = m.status;
    openModal('modal-member');
}

async function simpanMember() {
    const nama = document.getElementById('fm-nama').value.trim();
    const hp = document.getElementById('fm-hp').value.trim();
    if (!nama) { showToast('error', 'Nama member wajib diisi!'); return; }
    if (!hp) { showToast('error', 'No. HP wajib diisi!'); return; }

    const isEdit = editMemberIdx >= 0;
    const data = {
        id: isEdit ? DATA_MEMBER[editMemberIdx].id : null,
        nama,
        hp,
        email: document.getElementById('fm-email').value.trim(),
        alamat: document.getElementById('fm-alamat')?.value.trim() || '',
        totalBelanja: isEdit ? DATA_MEMBER[editMemberIdx].totalBelanja : 0,
        poin: isEdit ? DATA_MEMBER[editMemberIdx].poin : 0,
        status: document.getElementById('fm-status').value,
    };

    // dbUpsertMember sudah ada sejak awal tapi tidak pernah dipanggil dari sini,
    // sehingga data member tidak pernah sampai ke database.
    const savedId = await dbUpsertMember({
        id: data.id, nama, hp, email: data.email, alamat: data.alamat,
        poin: data.poin, spend: data.totalBelanja, status: data.status,
    });
    if (savedId) data.id = savedId;
    else { data.id = data.id || idLokal('MBR'); showToast('warning', 'Tersimpan lokal, gagal sync ke server.'); }

    if (isEdit) {
        DATA_MEMBER[editMemberIdx] = data;
        showToast('success', 'Member berhasil diperbarui!');
    } else {
        DATA_MEMBER.push(data);
        showToast('success', 'Member baru berhasil ditambahkan!');
    }

    closeModal('modal-member');
    renderMember();
}

function hapusMember(idx) {
    const m = DATA_MEMBER[idx];
    const piutang = piutangBerjalan(m.nama);
    if (piutang > 0) {
        showToast('error', `Member "${escapeHtml(m.nama)}" masih punya piutang ${formatRp(piutang)}. Lunasi dulu sebelum dihapus.`);
        return;
    }
    showConfirm('Hapus Member', `Yakin ingin menghapus member "${escapeHtml(m.nama)}"?`, async () => {
        await dbDeleteMember(m.id);
        DATA_MEMBER.splice(idx, 1);
        renderMember();
        showToast('success', 'Member berhasil dihapus.');
    });
}

// ── PENJUALAN ─────────────────────────────────────────────────────
function renderPenjualan(data) {
    data = data || DATA_PENJUALAN;
    const tbody = document.querySelector('#tbl-penjualan tbody');
    if (!tbody) return;
    tbody.innerHTML = data.length
        ? data.map(t => `
        <tr>
            <td><code class="inv-code">#${escapeHtml(t.id)}</code></td>
            <td>${formatTanggal(t.tanggal)}</td>
            <td>${escapeHtml(t.kasir)}</td>
            <td>${escapeHtml(t.pelanggan)}</td>
            <td>${escapeHtml(t.metode)}</td>
            <td>${formatRp(t.total)}</td>
            <td><span class="badge ${badgeStatus(t.status)}">${escapeHtml(t.status)}</span></td>
            <td><div class="td-actions">
                <button class="btn btn-info btn-sm" onclick="lihatDetailPenjualan('${escapeHtml(t.id)}')" aria-label="Lihat detail transaksi ${escapeHtml(t.id)}" title="Lihat Detail"><i data-lucide="eye"></i></button>
                ${t.status === 'Piutang' ? `<button class="btn btn-primary btn-sm" onclick="lunasiPiutang('${escapeHtml(t.id)}')">Lunasi</button>` : ''}
            </div></td>
        </tr>`).join('')
        : tableEmptyHTML(8, 'Tidak ada transaksi', 'Tidak ada data yang sesuai filter');
    const info = document.getElementById('info-penjualan');
    if (info) info.textContent = `Menampilkan ${data.length} dari ${DATA_PENJUALAN.length} data`;
    lucide.createIcons();
}

function lihatDetailPenjualan(id) {
    const t = DATA_PENJUALAN.find(x => x.id === id);
    if (!t) return;

    const itemsHtml = t.items && t.items.length
        ? `<table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:8px">
            <thead><tr style="background:var(--bg-2)">
                <th style="padding:7px 10px;text-align:left;border-bottom:1px solid var(--border)">Produk</th>
                <th style="padding:7px 10px;text-align:center;border-bottom:1px solid var(--border)">Qty</th>
                <th style="padding:7px 10px;text-align:right;border-bottom:1px solid var(--border)">Harga</th>
                <th style="padding:7px 10px;text-align:right;border-bottom:1px solid var(--border)">Subtotal</th>
            </tr></thead>
            <tbody>${t.items.map(i => `
                <tr>
                    <td style="padding:7px 10px;border-bottom:1px solid var(--border)">${escapeHtml(i.nama)}</td>
                    <td style="padding:7px 10px;text-align:center;border-bottom:1px solid var(--border)">${i.qty}</td>
                    <td style="padding:7px 10px;text-align:right;border-bottom:1px solid var(--border)">${formatRp(i.harga)}</td>
                    <td style="padding:7px 10px;text-align:right;border-bottom:1px solid var(--border)">${formatRp(i.harga * i.qty)}</td>
                </tr>`).join('')}
            </tbody>
           </table>`
        : '<p style="color:var(--text-3);font-size:13px;text-align:center;padding:16px 0">Detail item tidak tersedia</p>';

    document.getElementById('detail-trx-id').textContent      = '#' + t.id;
    document.getElementById('detail-trx-tanggal').textContent = formatTanggal(t.tanggal);
    document.getElementById('detail-trx-kasir').textContent   = t.kasir || '—';
    document.getElementById('detail-trx-pelanggan').textContent = t.pelanggan || 'Umum';
    document.getElementById('detail-trx-metode').textContent  = t.metode || '—';
    document.getElementById('detail-trx-status').innerHTML    = `<span class="badge ${badgeStatus(t.status)}">${escapeHtml(t.status)}</span>`;
    document.getElementById('detail-trx-total').textContent   = formatRp(t.total);
    document.getElementById('detail-trx-terbayar').textContent = formatRp(t.terbayar ?? 0);
    document.getElementById('detail-trx-sisa').textContent    = formatRp(Math.max(0, t.total - (t.terbayar ?? 0)));
    document.getElementById('detail-trx-items').innerHTML     = itemsHtml;

    openModal('modal-detail-trx');
    lucide.createIcons();
}

function filterPenjualan() {
    const status = document.getElementById('filter-status-jual')?.value || '';
    const metode = document.getElementById('filter-metode-jual')?.value || '';
    let data = DATA_PENJUALAN;
    if (status) data = data.filter(t => t.status === status);
    if (metode) data = data.filter(t => t.metode === metode);
    renderPenjualan(data);
}

// ── TAMBAH PENJUALAN (dengan info kredit reseller) ────────────────
function openTambahPenjualan() {
    document.getElementById('form-penjualan').reset();
    // Generate no faktur: INV-YYYYMMDD-NNN
    const today = hariIni().replace(/-/g, '');
    const prefix = 'INV-' + today + '-';
    const lastSame = DATA_PENJUALAN.filter(t => String(t.id).startsWith(prefix));
    const seq = String(lastSame.length + 1).padStart(3, '0');
    document.getElementById('fj-no').value      = prefix + seq;
    document.getElementById('fj-tanggal').value = hariIni();
    document.getElementById('fj-jenis').value   = 'Umum';
    document.getElementById('fj-reseller-wrap').style.display  = 'none';
    document.getElementById('fj-kredit-info').style.display    = 'none';
    document.getElementById('fj-member-wrap').style.display    = 'none';
    document.getElementById('fj-member-info').style.display    = 'none';
    document.getElementById('fj-nama-wrap').style.display      = '';
    document.getElementById('fj-dp-wrap').style.display        = 'none';
    // Isi dropdown reseller
    const sel = document.getElementById('fj-reseller');
    sel.innerHTML = '<option value="">-- Pilih Reseller --</option>' +
        DATA_RESELLER.map(r => `<option value="${escapeHtml(r.nama)}" data-idx="${DATA_RESELLER.indexOf(r)}">${escapeHtml(r.nama)}</option>`).join('');
    // Isi dropdown member
    const selM = document.getElementById('fj-member');
    if (selM) selM.innerHTML = '<option value="">-- Pilih Member --</option>' +
        DATA_MEMBER.filter(m => m.status === 'Aktif').map(m => `<option value="${escapeHtml(m.nama)}">${escapeHtml(m.nama)}</option>`).join('');
    openModal('modal-penjualan');
}

function onJenisPelangganJual() {
    const jenis = document.getElementById('fj-jenis').value;
    const isReseller = jenis === 'Reseller';
    const isMember   = jenis === 'Member';
    document.getElementById('fj-reseller-wrap').style.display = isReseller ? '' : 'none';
    document.getElementById('fj-kredit-info').style.display   = 'none';
    document.getElementById('fj-member-wrap').style.display   = isMember   ? '' : 'none';
    document.getElementById('fj-member-info').style.display   = 'none';
    document.getElementById('fj-nama-wrap').style.display     = (isReseller || isMember) ? 'none' : '';
    if (isReseller) document.getElementById('fj-reseller').value = '';
    if (isMember)   document.getElementById('fj-member').value   = '';
}

function onPilihMemberJual() {
    const nama = document.getElementById('fj-member').value;
    const infoBox = document.getElementById('fj-member-info');
    if (!nama) { infoBox.style.display = 'none'; return; }
    const m = DATA_MEMBER.find(x => x.nama === nama);
    if (!m) { infoBox.style.display = 'none'; return; }
    document.getElementById('fj-member-tier').textContent   = m.tier || 'Reguler';
    document.getElementById('fj-member-poin').textContent   = `${m.poin} poin`;
    document.getElementById('fj-member-belanja').textContent = formatRp(m.totalBelanja);
    infoBox.style.display = '';
}

function onPilihResellerJual() {
    const sel   = document.getElementById('fj-reseller');
    const nama  = sel.value;
    const infoBox = document.getElementById('fj-kredit-info');
    if (!nama) { infoBox.style.display = 'none'; return; }

    const r = DATA_RESELLER.find(x => x.nama === nama);
    if (!r) { infoBox.style.display = 'none'; return; }

    const limit    = Number(r.limitKredit || 0);
    const terpakai = piutangBerjalan(nama, r.id);
    const sisa     = limit - terpakai;
    const silaColor = sisa <= 0 ? 'var(--danger)' : (sisa < limit * 0.2 ? '#f59e0b' : 'var(--primary-light)');

    document.getElementById('fj-info-limit').textContent   = limit > 0 ? formatRp(limit) : 'Tidak ada limit';
    document.getElementById('fj-info-piutang').textContent = formatRp(terpakai);
    document.getElementById('fj-info-sisa').textContent    = limit > 0 ? formatRp(sisa) : '—';
    document.getElementById('fj-info-sisa').style.color    = silaColor;
    infoBox.style.display = '';
}

function onMetodeBayarJual() {
    const isPiutang = document.getElementById('fj-metode').value === 'Piutang';
    document.getElementById('fj-dp-wrap').style.display = isPiutang ? '' : 'none';
}

async function simpanPenjualanBaru() {
    const noFaktur = document.getElementById('fj-no').value.trim();
    const tanggal  = document.getElementById('fj-tanggal').value;
    const jenis    = document.getElementById('fj-jenis').value;
    const metode   = document.getElementById('fj-metode').value;
    const totalRaw = parseInt(document.getElementById('fj-total').value, 10) || 0;

    if (!tanggal)    { showToast('error', 'Tanggal wajib diisi!'); return; }
    if (totalRaw <= 0) { showToast('error', 'Total penjualan harus lebih dari 0!'); return; }

    let pelanggan = '';
    let idReseller = null;
    let resellerDiskon = 0;
    if (jenis === 'Reseller') {
        const nama = document.getElementById('fj-reseller').value;
        if (!nama) { showToast('error', 'Pilih reseller terlebih dahulu!'); return; }
        const r = DATA_RESELLER.find(x => x.nama === nama);
        if (r) {
            idReseller     = r.id || null;
            resellerDiskon = Number(r.diskon || 0);
            // Cek sisa limit kredit jika piutang — tampilkan warning, tidak blokir
            if (metode === 'Piutang' && r.limitKredit > 0) {
                const dp   = parseInt(document.getElementById('fj-dp').value, 10) || 0;
                const sisa = Number(r.limitKredit || 0) - piutangBerjalan(nama, r.id);
                const sisaBaru = totalRaw - dp;
                if (sisaBaru > sisa) {
                    showToast('warning', `Limit kredit "${nama}" terlampaui (sisa ${formatRp(sisa)}), transaksi tetap disimpan.`);
                }
            }
        }
        pelanggan = nama;
    } else if (jenis === 'Member') {
        const namaMember = document.getElementById('fj-member').value;
        if (!namaMember) { showToast('error', 'Pilih member terlebih dahulu!'); return; }
        const m = DATA_MEMBER.find(x => x.nama === namaMember);
        pelanggan = m ? m.nama : namaMember;
    } else {
        pelanggan = document.getElementById('fj-nama').value.trim() || 'Umum';
    }

    const isPiutang = metode === 'Piutang';
    const dp        = isPiutang ? (parseInt(document.getElementById('fj-dp').value, 10) || 0) : totalRaw;
    const status    = isPiutang ? 'Piutang' : 'Lunas';
    const metodeBayar = isPiutang ? 'Tunai' : metode;
    const kasir    = userSekarang()?.nama || userSekarang()?.username || 'Admin';

    const data = {
        id: noFaktur, dbId: null,
        tanggal, kasir, pelanggan,
        metode: metodeBayar, total: totalRaw,
        terbayar: dp, status,
        keterangan: document.getElementById('fj-keterangan').value.trim(),
        idReseller, resellerDiskon,
    };

    const savedId = await dbInsertTransaksi(data);
    if (savedId) {
        data.dbId = savedId;
    } else {
        showToast('warning', 'Tersimpan lokal, gagal sync ke server.');
    }

    DATA_PENJUALAN.unshift(data);
    // Kas masuk (penjualan Tunai / DP piutang) sekarang dicatat otomatis oleh
    // trigger DB fn_catat_kas_transaksi saat baris `transaksi` di-INSERT —
    // lihat supabase/migration_kas_shift_realtime.sql. Jangan catat manual di
    // sini lagi, supaya tidak dobel (dan supaya metode non-Tunai tidak lagi
    // salah ikut tercatat sebagai kas fisik).
    closeModal('modal-penjualan');
    renderPenjualan();
    if (isPiutang) renderPiutang();
    renderReseller();
    renderKas();
    updateDashboard();
    showToast('success', `Penjualan ${noFaktur} berhasil disimpan!`);
}

function lunasiPiutang(id) {
    const trx = DATA_PENJUALAN.find(t => t.id === id);
    if (!trx) { showToast('error', 'Transaksi tidak ditemukan.'); return; }
    const sisa = sisaTagihan(trx);

    showConfirm('Lunasi Piutang', `Tandai transaksi #${id} sebagai Lunas? Sisa ${formatRp(sisa)} akan dicatat sebagai pelunasan tunai.`, async () => {
        trx.terbayar = Number(trx.total || 0);
        trx.status = 'Lunas';
        if (sisa > 0) {
            // Pakai dbCatatPembayaran agar: (1) riwayat tersimpan di tabel pembayaran,
            // (2) transaksi.terbayar & status terupdate sekaligus dalam satu fungsi.
            const ok = await dbCatatPembayaran('piutang',
                { id: trx.dbId ?? trx.id, noReferensi: trx.id, terbayar: trx.terbayar, status: trx.status },
                sisa, 'Tunai', hariIni());
            if (!ok) showToast('warning', 'Pelunasan tercatat lokal, gagal sync ke server.');
            DATA_PEMBAYARAN.unshift({ jenis: 'piutang', ref: trx.id, nominal: sisa, metode: 'Tunai', tanggal: hariIni() });
            // Kas masuk dicatat otomatis oleh RPC catat_cicilan (server-side) — lihat
            // supabase/migration_kas_shift_realtime.sql, jangan catat manual di sini lagi.
        } else {
            // Sisa 0: tidak ada nominal baru, cukup update status saja.
            await dbLunasiPiutang(trx.dbId || trx.id, trx.terbayar);
        }
        renderPenjualan();
        renderPiutang();
        renderReseller();
        renderKas();
        renderLaporanPenjualan();
        renderLaporanPiutang();
        updateDashboard();
        showToast('success', `Piutang #${id} berhasil dilunasi!`);
    }, { type: 'primary', icon: 'check-circle', btnText: 'Ya, Lunasi' });
}

// ── USERS CRUD ────────────────────────────────────────────────────
let editUserIdx = -1;

function renderUsers() {
    const tbody = document.querySelector('#tbl-users tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_USERS.length
        ? DATA_USERS.map((u, i) => `
        <tr>
            <td>${escapeHtml(u.id)}</td>
            <td><div class="user-cell"><div class="avatar-circle" style="background:${escapeHtml(u.avatarColor)}">${escapeHtml(u.avatar)}</div><span>${escapeHtml(u.nama)}</span></div></td>
            <td><code>${escapeHtml(u.username)}</code></td>
            <td><span class="badge ${roleBadge(u.role)}">${escapeHtml(u.role)}</span></td>
            <td><span class="badge ${u.status === 'Aktif' ? 'badge-green' : 'badge-yellow'}">${escapeHtml(u.status)}</span></td>
            <td>${escapeHtml(u.lastLogin)}</td>
            <td><div class="td-actions">
                <button class="btn btn-info btn-sm" onclick="bukaEditUser(${i})" aria-label="Edit user ${escapeHtml(u.nama)}" title="Edit"><i data-lucide="pencil"></i></button>
                <button class="btn btn-danger btn-sm" onclick="hapusUser(${i})" aria-label="Nonaktifkan ${escapeHtml(u.nama)}" title="Nonaktifkan"><i data-lucide="user-x"></i></button>
            </div></td>
        </tr>`).join('')
        : tableSkeletonHTML(7, 4);
    document.getElementById('info-users').textContent = `Menampilkan ${DATA_USERS.length} data`;
    lucide.createIcons();
}

function openTambahUser() {
    editUserIdx = -1;
    document.getElementById('modal-user-title').textContent = 'Tambah User';
    document.getElementById('form-user').reset();
    document.getElementById('fu-status').value = 'Aktif';
    document.getElementById('fu-role').value = 'Admin';
    openModal('modal-user');
}

function bukaEditUser(idx) {
    editUserIdx = idx;
    const u = DATA_USERS[idx];
    document.getElementById('modal-user-title').textContent = 'Edit User';
    document.getElementById('fu-nama').value = u.nama;
    document.getElementById('fu-username').value = u.username;
    document.getElementById('fu-role').value = u.role;
    document.getElementById('fu-status').value = u.status;
    document.getElementById('fu-pass').value = '';
    document.getElementById('fu-pass2').value = '';
    openModal('modal-user');
}

async function simpanUser() {
    const nama     = document.getElementById('fu-nama').value.trim();
    const username = document.getElementById('fu-username').value.trim().toLowerCase();
    const role     = document.getElementById('fu-role').value;
    const status   = document.getElementById('fu-status').value;
    const pass     = document.getElementById('fu-pass').value;
    const pass2    = document.getElementById('fu-pass2').value;

    if (!nama)     { showToast('error', 'Nama lengkap wajib diisi!'); return; }
    if (!username) { showToast('error', 'Username wajib diisi!'); return; }
    if (editUserIdx < 0 && !pass) { showToast('error', 'Password wajib diisi untuk user baru!'); return; }
    if (pass && pass.length < 6) { showToast('error', 'Password minimal 6 karakter!'); return; }
    if (pass && pass !== pass2)  { showToast('error', 'Konfirmasi password tidak cocok!'); return; }

    const existing = DATA_USERS.find((u, i) => u.username === username && i !== editUserIdx);
    if (existing) { showToast('error', 'Username sudah digunakan!'); return; }

    const roleColors = { 'Owner': '#16A34A', 'Admin': '#8B5CF6', 'Kasir': '#3B82F6' };
    const payload = {
        id:          editUserIdx >= 0 ? DATA_USERS[editUserIdx].id : null,
        nama, username, role, status,
        avatarColor: roleColors[role] || '#16A34A',
    };

    const savedId = await dbUpsertProfile(payload, pass || null);
    if (savedId === null) {
        showToast('error', 'Gagal menyimpan ke database!');
        return;
    }

    // Refresh local list from DB
    const freshProfiles = await dbLoadProfiles();
    DATA_USERS.length = 0;
    for (const p of freshProfiles) {
        DATA_USERS.push({
            id: p.id?.toString() ?? '',
            nama: p.nama, username: p.username, role: p.role,
            status: p.aktif === false ? 'Non-aktif' : 'Aktif',
            lastLogin: '—',
            avatar: p.nama?.[0]?.toUpperCase() ?? '?',
            avatarColor: p.avatar_color ?? '#16A34A',
        });
    }

    closeModal('modal-user');
    renderUsers();
    showToast('success', editUserIdx >= 0 ? 'User berhasil diperbarui!' : 'User baru berhasil ditambahkan!');
}

function hapusUser(idx) {
    const u = DATA_USERS[idx];
    const currentUser = JSON.parse(localStorage.getItem('ugt_user') || '{}');
    if (u.username === currentUser.username) {
        showToast('error', 'Tidak bisa menonaktifkan akun yang sedang digunakan!');
        return;
    }
    showConfirm('Nonaktifkan User', `Yakin ingin menonaktifkan user "${escapeHtml(u.nama)}"? User tidak akan bisa login.`, async () => {
        const ok = await dbDeactivateProfile(u.id);
        if (!ok) { showToast('error', 'Gagal menonaktifkan user!'); return; }
        DATA_USERS[idx].status = 'Non-aktif';
        renderUsers();
        showToast('success', 'User berhasil dinonaktifkan.');
    }, { type: 'warning', icon: 'user-x', btnText: 'Ya, Nonaktifkan' });
}

// ── LAPORAN STOK ──────────────────────────────────────────────────
function renderLaporanStok(data) {
    data = data || DATA_BARANG;
    const tbody = document.querySelector('#tbl-lap-stok tbody');
    if (!tbody) return;
    tbody.innerHTML = data.length
        ? data.map(b => {
            const statusStok = b.stok === 0 ? 'Habis' : (b.stok <= b.stokMin ? 'Hampir Habis' : 'Normal');
            const badgeStok = b.stok === 0 ? 'badge-red' : (b.stok <= b.stokMin ? 'badge-yellow' : 'badge-green');
            return `<tr>
                <td>${escapeHtml(b.id)}</td>
                <td>${escapeHtml(b.nama)}</td>
                <td>${escapeHtml(b.kategori)}</td>
                <td>${b.stok} ${escapeHtml(b.satuan)}</td>
                <td>${b.stokMin}</td>
                <td>${formatRp(b.stok * b.hargaBeli)}</td>
                <td><span class="badge ${badgeStok}">${statusStok}</span></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(7, 'Tidak ada data stok', 'Coba ubah filter kategori');
    const info = document.getElementById('info-lap-stok');
    if (info) info.textContent = `Menampilkan ${data.length} dari ${DATA_BARANG.length} data`;
    lucide.createIcons();
}

function filterLaporanStok(kategori) {
    const data = kategori ? DATA_BARANG.filter(b => b.kategori === kategori) : DATA_BARANG;
    renderLaporanStok(data);
}

function populateLapStokKategori() {
    const sel = document.getElementById('lap-stok-kategori');
    if (!sel) return;
    const existing = [...sel.options].map(o => o.value);
    DATA_KATEGORI.forEach(k => {
        if (!existing.includes(k.nama)) {
            const opt = document.createElement('option');
            opt.value = k.nama; opt.textContent = k.nama;
            sel.appendChild(opt);
        }
    });
}

// ── LAPORAN PENJUALAN ─────────────────────────────────────────────
function renderLaporanPenjualan(data) {
    data = data || DATA_PENJUALAN;
    const tbody = document.querySelector('#tbl-lap-penjualan tbody');
    if (!tbody) return;
    tbody.innerHTML = data.length
        ? data.map(t => `<tr>
            <td>${formatTanggal(t.tanggal)}</td>
            <td><code class="inv-code">#${escapeHtml(t.id)}</code></td>
            <td>${escapeHtml(t.kasir)}</td>
            <td>${escapeHtml(t.pelanggan)}</td>
            <td>${escapeHtml(t.metode)}</td>
            <td>${formatRp(t.total)}</td>
            <td><span class="badge ${badgeStatus(t.status)}">${escapeHtml(t.status)}</span></td>
        </tr>`).join('')
        : '<tr><td colspan="7" style="text-align:center;color:var(--text-3);padding:20px">Tidak ada data untuk filter yang dipilih</td></tr>';

    const totalSemua = data.reduce((s, t) => s + t.total, 0);
    const lunas     = data.filter(t => t.status === 'Lunas').length;
    const rata      = data.length ? Math.round(totalSemua / data.length) : 0;

    const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setEl('lap-pj-total', formatRp(totalSemua));
    setEl('lap-pj-count', data.length.toLocaleString('id-ID'));
    setEl('lap-pj-rata',  formatRp(rata));
    setEl('lap-pj-lunas', `${lunas} / ${data.length}`);
    setEl('info-lap-penjualan', `Menampilkan ${data.length} dari ${DATA_PENJUALAN.length} data`);
    lucide.createIcons();
}

function filterLaporanPenjualan() {
    const dari   = document.getElementById('lap-tgl-dari')?.value;
    const sampai = document.getElementById('lap-tgl-sampai')?.value;
    const kasir  = document.getElementById('lap-kasir')?.value;
    const metode = document.getElementById('lap-metode')?.value;
    let data = DATA_PENJUALAN;
    if (dari)   data = data.filter(t => t.tanggal >= dari);
    if (sampai) data = data.filter(t => t.tanggal <= sampai);
    if (kasir)  data = data.filter(t => t.kasir === kasir);
    if (metode) data = data.filter(t => t.metode === metode);
    renderLaporanPenjualan(data);
}

// ── LAPORAN PIUTANG ───────────────────────────────────────────────
function renderLaporanPiutang() {
    const piutang = DATA_PENJUALAN.filter(t => t.status === 'Piutang');
    const lunas   = DATA_PENJUALAN.filter(t => t.status === 'Lunas').length;
    const tbody   = document.querySelector('#tbl-lap-piutang tbody');
    if (!tbody) return;

    tbody.innerHTML = piutang.length
        ? piutang.map(t => `<tr>
            <td>${escapeHtml(t.pelanggan)}</td>
            <td><code class="inv-code">#${escapeHtml(t.id)}</code></td>
            <td>${formatTanggal(t.tanggal)}</td>
            <td>${escapeHtml(t.metode)}</td>
            <td>${formatRp(sisaTagihan(t))}</td>
            <td><button class="btn btn-primary btn-sm" onclick="lunasiPiutang('${escapeHtml(t.id)}')">Lunasi</button></td>
        </tr>`).join('')
        : '<tr><td colspan="6" style="text-align:center;color:var(--text-3);padding:20px">Tidak ada piutang aktif</td></tr>';

    const totalPiutang = piutang.reduce((s, t) => s + sisaTagihan(t), 0);
    const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setEl('lap-piutang-total', formatRp(totalPiutang));
    setEl('lap-piutang-count', `${piutang.length} tagihan`);
    setEl('lap-piutang-lunas', `${lunas} transaksi`);
    setEl('info-lap-piutang', `Menampilkan ${piutang.length} data`);
    lucide.createIcons();
}

// ── TABLE HELPERS ─────────────────────────────────────────────────
function tableEmptyHTML(colSpan, msg = 'Tidak ada data', sub = '') {
    return `<tr><td colspan="${colSpan}" style="padding:0">
        <div class="table-empty-state">
            <i data-lucide="inbox"></i>
            <strong>${escapeHtml(msg)}</strong>
            ${sub ? `<p>${escapeHtml(sub)}</p>` : ''}
        </div>
    </td></tr>`;
}

function tableSkeletonHTML(colSpan, rows = 3) {
    return Array.from({ length: rows }, () =>
        `<tr class="skeleton-row">${Array.from({ length: colSpan }, () =>
            `<td><div class="skeleton"></div></td>`).join('')}</tr>`
    ).join('');
}

// ── HELPERS ──────────────────────────────────────────────────────
function generateId(prefix, arr) {
    // Dulu langsung `x.id.split(...)`, sehingga satu record dengan id null saja
    // (terjadi setelah simpan gagal sync ke server) membuat seluruh tombol
    // "Tambah" crash. Sekarang record tanpa id cukup dilewati.
    const nums = arr
        .map(x => parseInt(String(x?.id ?? '').split('-').pop(), 10))
        .filter(n => !isNaN(n));
    const next = nums.length ? Math.max(...nums) + 1 : 1;
    return `${prefix}-${String(next).padStart(3, '0')}`;
}

function formatRp(num) {
    return 'Rp ' + Number(num).toLocaleString('id-ID');
}

function formatTanggal(str) {
    if (!str) return '—';
    const d = new Date(str);
    return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

function badgeStatus(status) {
    const map = { 'Lunas': 'badge-green', 'Piutang': 'badge-yellow', 'Proses': 'badge-blue', 'Pending': 'badge-orange' };
    return map[status] || 'badge-gray';
}

function roleBadge(role) {
    const map = { 'Owner': 'badge-green', 'Admin': 'badge-purple', 'Kasir': 'badge-blue' };
    return map[role] || 'badge-gray';
}

// ── INITIALIZATION ────────────────────────────────────────────────
window._loginBgFrameId = 0;

function initLoginBackground() {
    const canvas = document.getElementById('login-canvas');
    const container = canvas?.parentElement;
    if (!canvas || !container) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    let width = 0, height = 0, particles = [], frameId = 0;
    const mouse = { x: -1000, y: -1000 };

    function createParticle() {
        return {
            x: Math.random() * width, y: Math.random() * height, vx: 0, vy: 0, age: 0,
            life: Math.random() * 220 + 120,
            update() {
                const angle = (Math.cos(this.x * 0.0045) + Math.sin(this.y * 0.0045)) * Math.PI;
                this.vx += Math.cos(angle) * 0.16; this.vy += Math.sin(angle) * 0.16;
                const dx = mouse.x - this.x, dy = mouse.y - this.y;
                const dist = Math.sqrt(dx * dx + dy * dy), radius = 150;
                if (dist < radius) { const f = (radius - dist) / radius; this.vx -= dx * f * 0.05; this.vy -= dy * f * 0.05; }
                this.x += this.vx; this.y += this.vy; this.vx *= 0.95; this.vy *= 0.95; this.age++;
                if (this.age > this.life) this.reset();
                if (this.x < 0) this.x = width; if (this.x > width) this.x = 0;
                if (this.y < 0) this.y = height; if (this.y > height) this.y = 0;
            },
            reset() { this.x = Math.random() * width; this.y = Math.random() * height; this.vx = 0; this.vy = 0; this.age = 0; this.life = Math.random() * 220 + 120; },
            draw() { ctx.fillStyle = '#818cf8'; const alpha = 1 - Math.abs((this.age / this.life) - 0.5) * 2; ctx.globalAlpha = Math.max(0.08, alpha); ctx.fillRect(this.x, this.y, 1.4, 1.4); ctx.globalAlpha = 1; }
        };
    }
    function resize() {
        const dpr = window.devicePixelRatio || 1, rect = container.getBoundingClientRect();
        width = rect.width; height = rect.height;
        canvas.width = width * dpr; canvas.height = height * dpr;
        canvas.style.width = `${width}px`; canvas.style.height = `${height}px`;
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        particles = Array.from({ length: 650 }, createParticle);
    }
    function animate() {
        ctx.clearRect(0, 0, width, height); ctx.fillStyle = 'rgba(2,6,23,0.14)'; ctx.fillRect(0, 0, width, height);
        particles.forEach(p => { p.update(); p.draw(); });
        frameId = window.requestAnimationFrame(animate);
        window._loginBgFrameId = frameId;
    }
    resize(); animate();
    window.addEventListener('resize', resize);
    container.addEventListener('mousemove', e => { const r = canvas.getBoundingClientRect(); mouse.x = e.clientX - r.left; mouse.y = e.clientY - r.top; });
    container.addEventListener('mouseleave', () => { mouse.x = -1000; mouse.y = -1000; });
}

function updateDateTime() {
    const el = document.getElementById('topbar-date');
    if (el) el.textContent = new Date().toLocaleDateString('id-ID', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
}
updateDateTime();
setInterval(updateDateTime, 60000);

function isMobile() { return window.innerWidth <= 768; }

function openMobileSidebar() {
    const sb = document.getElementById('sidebar'), ov = document.getElementById('sidebar-overlay');
    sb.classList.add('mobile-open'); sb.classList.remove('collapsed');
    ov.style.display = 'block'; requestAnimationFrame(() => ov.classList.add('visible'));
    document.body.style.overflow = 'hidden';
}

function closeMobileSidebar() {
    const sb = document.getElementById('sidebar'), ov = document.getElementById('sidebar-overlay');
    sb.classList.remove('mobile-open'); ov.classList.remove('visible');
    setTimeout(() => { ov.style.display = 'none'; }, 300);
    document.body.style.overflow = '';
}

function toggleSidebar() {
    if (isMobile()) {
        const sb = document.getElementById('sidebar');
        sb.classList.contains('mobile-open') ? closeMobileSidebar() : openMobileSidebar();
    } else {
        document.getElementById('sidebar').classList.toggle('collapsed');
        document.getElementById('main-wrapper').classList.toggle('expanded');
    }
}

function setBotNav(el) {
    document.querySelectorAll('.bot-nav-item').forEach(b => b.classList.remove('active'));
    if (el) el.classList.add('active');
}

window.addEventListener('resize', () => {
    if (!isMobile()) {
        const ov = document.getElementById('sidebar-overlay');
        ov.classList.remove('visible'); ov.style.display = 'none';
        document.getElementById('sidebar').classList.remove('mobile-open');
        document.body.style.overflow = '';
    }
});

// ── NAVIGATION ───────────────────────────────────────────────────
function navigate(pageId, el, label) {
    // Penjaga akses: menu yang disembunyikan tetap bisa dipanggil lewat konsol
    // atau tombol lain, jadi pengecekan diulang di sini.
    if (localStorage.getItem('ugt_logged') && !bolehAkses(pageId)) {
        showToast('warning', '🔒 Akses terbatas: halaman ini bukan untuk peran Anda.');
        return;
    }
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    const target = document.getElementById('page-' + pageId);
    if (target) target.classList.add('active');

    const bc = document.getElementById('breadcrumb-label');
    if (bc) bc.textContent = label ? label.split(' > ').pop() : pageId;

    document.querySelectorAll('.nav-item, .nav-sub-item, .nav-sub-sub-item').forEach(n => n.classList.remove('active'));
    if (el) { el.classList.add('active'); }
    else { const found = document.querySelector('[data-page="' + pageId + '"]'); if (found) found.classList.add('active'); }

    if (isMobile()) closeMobileSidebar();
    const ca = document.getElementById('content-area');
    if (ca) ca.scrollTop = 0;
    lucide.createIcons();
}

function toggleSubMenu(id, el) {
    const sub = document.getElementById(id), chev = document.getElementById('chev-' + id);
    if (sub) sub.classList.toggle('open');
    if (chev) chev.classList.toggle('open');
}

function toggleSubSubMenu(id, el) {
    const sub = document.getElementById(id), chev = document.getElementById('chev-' + id);
    if (sub) sub.classList.toggle('open');
    if (chev) chev.classList.toggle('open');
}

// ── MODALS ───────────────────────────────────────────────────────
function openModal(id) {
    const m = document.getElementById(id);
    if (m) { m.classList.add('open'); document.body.style.overflow = 'hidden'; }
    lucide.createIcons();
}

function closeModal(id) {
    const m = document.getElementById(id);
    if (m) { m.classList.remove('open'); document.body.style.overflow = ''; }
}

document.querySelectorAll('.modal-overlay').forEach(overlay => {
    overlay.addEventListener('click', function(e) { if (e.target === overlay) closeModal(overlay.id); });
});

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') document.querySelectorAll('.modal-overlay.open').forEach(m => closeModal(m.id));
});

// ── SETTINGS PANELS ──────────────────────────────────────────────
function showSettingsPanel(id, el) {
    document.querySelectorAll('.settings-panel').forEach(p => p.style.display = 'none');
    const panel = document.getElementById(id);
    if (panel) panel.style.display = 'block';
    document.querySelectorAll('.settings-nav-item').forEach(i => i.classList.remove('active'));
    if (el) el.classList.add('active');
    lucide.createIcons();
}

// ── TABLE FILTER ─────────────────────────────────────────────────
function filterTable(input, tableId, colIndex) {
    const term = (typeof input === 'string' ? input : input.value).toLowerCase();
    document.querySelectorAll('#' + tableId + ' tbody tr').forEach(row => {
        const cell = row.cells[colIndex];
        if (cell) row.style.display = cell.textContent.toLowerCase().includes(term) ? '' : 'none';
    });
}

// ── FULLSCREEN ───────────────────────────────────────────────────
function toggleFullscreen() {
    if (!document.fullscreenElement) document.documentElement.requestFullscreen().catch(() => {});
    else document.exitFullscreen().catch(() => {});
}

// ── CHARTS ───────────────────────────────────────────────────────
function initCharts() {
    const ctxSales = document.getElementById('chartSales');
    if (ctxSales && !ctxSales._chart) {
        const now      = new Date();
        const curMonth = now.getMonth();
        const curYear  = now.getFullYear();
        const salesData = Array(12).fill(null);
        const buyData   = Array(12).fill(null);
        for (let m = 0; m <= curMonth; m++) {
            salesData[m] = +(DATA_PENJUALAN
                .filter(t => { const d = new Date(t.tanggal); return d.getMonth() === m && d.getFullYear() === curYear; })
                .reduce((s, t) => s + t.total, 0) / 1000000).toFixed(2);
            buyData[m] = +(DATA_PEMBELIAN
                .filter(p => { const d = new Date(p.tanggal); return d.getMonth() === m && d.getFullYear() === curYear; })
                .reduce((s, p) => s + p.total, 0) / 1000000).toFixed(2);
        }

        ctxSales._chart = new Chart(ctxSales, {
            type: 'line',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'],
                datasets: [
                    { label: 'Penjualan (Juta)', data: salesData, borderColor: '#16A34A', backgroundColor: 'rgba(22,163,74,0.08)', fill: true, tension: 0.4, pointBackgroundColor: '#16A34A', pointRadius: 4, pointHoverRadius: 6, borderWidth: 2.5 },
                    { label: 'Pembelian (Juta)', data: buyData,   borderColor: '#3B82F6', backgroundColor: 'rgba(59,130,246,0.06)', fill: true, tension: 0.4, pointBackgroundColor: '#3B82F6', pointRadius: 4, pointHoverRadius: 6, borderWidth: 2.5 }
                ]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'top', labels: { usePointStyle: true, font: { size: 11, family: 'Inter' }, padding: 16 } }, tooltip: { mode: 'index', intersect: false } }, scales: { x: { grid: { display: false }, ticks: { font: { size: 11 }, color: '#94A3B8' } }, y: { grid: { color: 'rgba(0,0,0,0.04)' }, ticks: { font: { size: 11 }, color: '#94A3B8', callback: v => v ? v + 'jt' : '0' }, beginAtZero: true } } }
        });
    }
}

// ── DARK MODE ────────────────────────────────────────────────────
function toggleDarkMode() {
    document.body.classList.toggle('dark');
    const isDark = document.body.classList.contains('dark');
    localStorage.setItem('ugt_dark', isDark ? '1' : '0');
    const icon = document.getElementById('dark-icon');
    if (icon) { icon.setAttribute('data-lucide', isDark ? 'sun' : 'moon'); lucide.createIcons(); }
    showToast('info', isDark ? 'Mode gelap diaktifkan' : 'Mode terang diaktifkan');
}

(function() {
    if (localStorage.getItem('ugt_dark') === '1') {
        document.body.classList.add('dark');
        window.addEventListener('load', () => {
            const icon = document.getElementById('dark-icon');
            if (icon) { icon.setAttribute('data-lucide', 'sun'); lucide.createIcons(); }
        });
    }
})();

// ── TOAST ────────────────────────────────────────────────────────
function showToast(type, msg, duration) {
    duration = duration || 3500;
    const icons = { success: 'check-circle', error: 'x-circle', warning: 'alert-triangle', info: 'info' };
    const container = document.getElementById('toast-container');
    if (!container) return;
    const t = document.createElement('div');
    t.className = 'toast toast-' + type;
    t.innerHTML = `<svg class="toast-icon" data-lucide="${icons[type]||'info'}"></svg><span class="toast-msg">${escapeHtml(msg)}</span><svg class="toast-close" data-lucide="x" onclick="this.parentElement.remove()"></svg>`;
    container.appendChild(t);
    lucide.createIcons();
    setTimeout(() => {
        if (t.parentElement) { t.style.animation = 'toastOut 0.3s ease forwards'; setTimeout(() => t.remove(), 300); }
    }, duration);
}

// ── CONFIRM DIALOG ───────────────────────────────────────────────
let confirmCallback = null;

function showConfirm(title, msg, onConfirm, opts = {}) {
    const type    = opts.type    || 'danger';
    const icon    = opts.icon    || (type === 'danger' ? 'trash-2' : type === 'primary' ? 'check-circle' : 'alert-triangle');
    const btnText = opts.btnText || (type === 'danger' ? 'Ya, Hapus' : type === 'primary' ? 'Ya, Lanjutkan' : 'Ya, Lanjutkan');
    const btnClass = type === 'danger' ? 'btn-danger' : type === 'primary' ? 'btn-primary' : 'btn-warning';

    confirmCallback = onConfirm;
    document.getElementById('confirm-title').textContent = title;
    document.getElementById('confirm-msg').textContent = msg;

    const iconWrap = document.getElementById('confirm-icon-wrap');
    const iconEl   = document.getElementById('confirm-icon-el');
    const okBtn    = document.getElementById('confirm-ok-btn');
    const okIcon   = document.getElementById('confirm-ok-icon');
    const okText   = document.getElementById('confirm-ok-text');

    iconWrap.className = `confirm-icon${type !== 'danger' ? ' ' + type : ''}`;
    iconEl.setAttribute('data-lucide', icon);
    okBtn.className = `btn ${btnClass}`;
    okIcon.setAttribute('data-lucide', icon);
    okText.textContent = btnText;

    document.getElementById('confirm-overlay').classList.add('open');
    lucide.createIcons();
}

function closeConfirm() { document.getElementById('confirm-overlay').classList.remove('open'); }

function doConfirm() {
    closeConfirm();
    if (typeof confirmCallback === 'function') confirmCallback();
    confirmCallback = null;
}

// ── NOTIFICATION PANEL ───────────────────────────────────────────
function toggleNotifPanel() {
    const panel = document.getElementById('notif-panel');
    panel.classList.toggle('open');
    if (panel.classList.contains('open')) {
        document.getElementById('notif-dot').style.display = 'none';
        document.querySelectorAll('.notif-item.unread').forEach(i => i.classList.remove('unread'));
    }
}

function tandaiSemuaNotifDibaca() {
    document.querySelectorAll('.notif-item.unread').forEach(i => i.classList.remove('unread'));
    document.getElementById('notif-dot').style.display = 'none';
    showToast('success', 'Semua notifikasi telah ditandai dibaca.');
}

document.addEventListener('click', function(e) {
    const panel = document.getElementById('notif-panel');
    if (!panel || !panel.classList.contains('open')) return;
    if (!panel.contains(e.target) && !e.target.closest('[onclick*="toggleNotifPanel"]')) panel.classList.remove('open');
});

// ── GENERAL BUTTON FEEDBACK ──────────────────────────────────────
document.addEventListener('click', function(e) {
    const btn = e.target.closest('.btn');
    if (!btn) return;
    const txt = btn.textContent.trim().toLowerCase();
    if (txt.includes('refresh')) { showToast('info', 'Data sedang diperbarui...'); setTimeout(() => showToast('success', 'Dashboard berhasil diperbarui!'), 1200); }
    if (txt.includes('cetak') || txt.includes('print')) showToast('info', 'Mengirim ke printer...');
});

// ── APP START ────────────────────────────────────────────────────
document.addEventListener('keydown', e => {
    const ls = document.getElementById('login-screen');
    if (ls && ls.style.display !== 'none' && e.key === 'Enter') doLogin();
});

window.addEventListener('load', async () => {
    lucide.createIcons();
    initLoginBackground();
    const today = new Date().toISOString().split('T')[0];
    document.querySelectorAll('input[type="date"]').forEach(d => { if (!d.value) d.value = today; });

    if (localStorage.getItem('ugt_logged')) {
        const savedToko = localStorage.getItem('ugt_id_toko');
        if (!savedToko) {
            // Sesi lama tidak punya id_toko (login sebelum multi-tenancy) — paksa login ulang
            localStorage.removeItem('ugt_logged');
            localStorage.removeItem('ugt_user');
            muatPengaturan();
        } else {
            // Pulihkan scope toko dari sesi sebelumnya lalu muat ulang data
            setCurrentToko(savedToko);
            try { await dbLoadAll(); } catch {}
            try {
                const hasil = await dbLoadAllExtra();
                if (hasil.gagal.length) {
                    console.info('Tabel belum tersedia di server (mode lokal):', hasil.gagal.join(', '),
                                 '— jalankan blok MIGRASI v2.1 di schema.sql.');
                }
            } catch (e) { console.warn('dbLoadAllExtra:', e); }
            muatPengaturan();
            showApp();
        }
    } else {
        muatPengaturan();
    }
});

/* ══════════════════════════════════════════════════════════════════════════════
   MODUL v1.1 — Melengkapi halaman yang sebelumnya hanya tampilan statis:
   Cabang, Reseller, Pembelian, Retur Beli/Jual, Pelunasan Piutang & Hutang,
   Kas Kasir, Stock Opname, Penyesuaian Stok, dan 3 laporan yang belum jalan.

   Logika bisnisnya diambil dari panel modular (web_ugt_martdan) lalu
   disambungkan ke Supabase, dengan beberapa perbaikan:
     • mutasi stok hanya mengenai barang yang dipilih (bukan semua barang)
     • cicilan hutang/piutang divalidasi terhadap sisa tagihan
     • limit kredit reseller dicek dari piutang yang masih berjalan
   ══════════════════════════════════════════════════════════════════════════════ */

// ── DATA ARRAYS BARU ─────────────────────────────────────────────────────────
let DATA_CABANG     = [];
let DATA_RESELLER   = [];
let DATA_PEMBELIAN  = [];
let DATA_RETUR_BELI = [];
let DATA_RETUR_JUAL = [];
let DATA_KAS        = [];
let DATA_OPNAME     = [];
let DATA_ADJ        = [];
let DATA_PEMBAYARAN = [];
let DATA_STOK_LOG   = [];
let DATA_SHIFT_AKTIF = null;
let DATA_SHIFT_LIST  = [];

// ── HELPER UMUM ──────────────────────────────────────────────────────────────
function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function hariIni() {
    // Tanggal lokal (WIB), BUKAN toISOString() yang UTC — supaya jam 00:00-06:59
    // WIB tidak salah mundur 1 hari.
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const t = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${t}`;
}

function tambahHari(tanggal, jumlah) {
    const d = tanggal ? new Date(tanggal) : new Date();
    if (isNaN(d.getTime())) return hariIni();
    d.setDate(d.getDate() + jumlah);
    return d.toISOString().split('T')[0];
}

function nextKode(prefix, arr, field = 'id') {
    const nums = arr
        .map(x => parseInt(String(x[field] ?? '').split('-').pop(), 10))
        .filter(n => !isNaN(n));
    const next = nums.length ? Math.max(...nums) + 1 : 1;
    return `${prefix}-${String(next).padStart(3, '0')}`;
}

// Saat sync ke server gagal, record tetap butuh id agar bisa dirujuk dropdown
// dan tombol aksi. Sebelumnya id dibiarkan null sehingga entitas jadi "hantu":
// tampil di tabel tapi tidak bisa dipilih di mana pun.
function idLokal(prefix) {
    return `${prefix}-LOKAL-${Date.now().toString().slice(-6)}`;
}

function userSekarang() {
    try { return JSON.parse(localStorage.getItem('ugt_user') || '{}'); }
    catch { return {}; }
}

function namaPetugas() {
    return userSekarang().nama || 'Sistem';
}

function sisaTagihan(item) {
    return Math.max(0, Number(item.total || 0) - Number(item.terbayar || 0));
}

function lewatJatuhTempo(tanggal) {
    if (!tanggal) return false;
    return tanggal < hariIni();
}

// Mengubah stok satu barang saja, lalu sinkron ke database.
// Mengembalikan false bila barang tidak ditemukan atau stok jadi negatif.
async function terapkanStok(namaProduk, delta) {
    if (!namaProduk || !delta) return true;
    const barang = DATA_BARANG.find(b => b.nama === namaProduk);
    if (!barang) return false;
    const stokBaru = Number(barang.stok || 0) + Number(delta);
    if (stokBaru < 0) return false;
    barang.stok = stokBaru;
    await dbUpdateStok(barang.id, stokBaru);
    renderBarang();
    renderLaporanStok();
    updateDashboard();
    return true;
}

// ── CABANG ───────────────────────────────────────────────────────────────────
let editCabangIdx = -1;

function renderCabang() {
    const tbody = document.querySelector('#tbl-cabang tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_CABANG.length
        ? DATA_CABANG.map((c, i) => `
        <tr>
            <td>${escapeHtml(c.kode || c.id)}</td>
            <td><strong>${escapeHtml(c.nama)}</strong></td>
            <td>${escapeHtml(c.alamat) || '—'}</td>
            <td>${escapeHtml(c.kontak) || '—'}</td>
            <td><span class="badge ${c.status === 'Aktif' ? 'badge-green' : 'badge-yellow'}">${escapeHtml(c.status)}</span></td>
            <td><div class="td-actions">
                <button class="btn btn-info btn-sm" onclick="bukaEditCabang(${i})" aria-label="Edit ${escapeHtml(c.nama)}" title="Edit"><i data-lucide="pencil"></i></button>
                <button class="btn btn-danger btn-sm" onclick="hapusCabang(${i})" aria-label="Hapus ${escapeHtml(c.nama)}" title="Hapus"><i data-lucide="trash-2"></i></button>
            </div></td>
        </tr>`).join('')
        : tableEmptyHTML(6, 'Belum ada cabang', 'Klik Tambah Cabang untuk memulai');
    const info = document.getElementById('info-cabang');
    if (info) info.textContent = `Menampilkan ${DATA_CABANG.length} data`;
    lucide.createIcons();
}

function openTambahCabang() {
    editCabangIdx = -1;
    document.getElementById('modal-cabang-title').textContent = 'Tambah Cabang';
    document.getElementById('form-cabang').reset();
    document.getElementById('fc-kode').value = nextKode('CBG', DATA_CABANG, 'kode');
    document.getElementById('fc-status').value = 'Aktif';
    openModal('modal-cabang');
}

function bukaEditCabang(idx) {
    editCabangIdx = idx;
    const c = DATA_CABANG[idx];
    document.getElementById('modal-cabang-title').textContent = 'Edit Cabang';
    document.getElementById('fc-kode').value    = c.kode || '';
    document.getElementById('fc-nama').value    = c.nama;
    document.getElementById('fc-kontak').value  = c.kontak || '';
    document.getElementById('fc-pic').value     = c.pic || '';
    document.getElementById('fc-alamat').value  = c.alamat || '';
    document.getElementById('fc-status').value  = c.status;
    openModal('modal-cabang');
}

async function simpanCabang() {
    const nama = document.getElementById('fc-nama').value.trim();
    if (!nama) { showToast('error', 'Nama cabang wajib diisi!'); return; }

    const isEdit = editCabangIdx >= 0;
    const data = {
        id:     isEdit ? DATA_CABANG[editCabangIdx].id : null,
        kode:   document.getElementById('fc-kode').value,
        nama,
        kontak: document.getElementById('fc-kontak').value.trim(),
        pic:    document.getElementById('fc-pic').value.trim(),
        alamat: document.getElementById('fc-alamat').value.trim(),
        status: document.getElementById('fc-status').value,
    };

    const savedId = await dbUpsertCabang(data);
    if (savedId) data.id = savedId;
    else { data.id = data.id || idLokal('CBG'); showToast('warning', 'Tersimpan lokal, gagal sync ke server.'); }

    if (isEdit) DATA_CABANG[editCabangIdx] = data;
    else DATA_CABANG.push(data);

    closeModal('modal-cabang');
    renderCabang();
    showToast('success', isEdit ? 'Cabang berhasil diperbarui!' : 'Cabang baru berhasil ditambahkan!');
}

function hapusCabang(idx) {
    const c = DATA_CABANG[idx];
    showConfirm('Hapus Cabang', `Yakin ingin menghapus cabang "${c.nama}"?`, async () => {
        const ok = await dbDeleteCabang(c.id);
        if (!ok) { showToast('error', 'Gagal menghapus cabang dari database!'); return; }
        DATA_CABANG.splice(idx, 1);
        renderCabang();
        showToast('success', 'Cabang berhasil dihapus.');
    });
}

// ── RESELLER ─────────────────────────────────────────────────────────────────
let editResellerIdx = -1;

// Piutang berjalan milik satu reseller — dipakai untuk cek limit kredit.
function piutangBerjalan(namaPelanggan, idReseller) {
    return DATA_PENJUALAN
        .filter(t => {
            if (t.status !== 'Piutang') return false;
            // Prioritaskan id-based matching agar tidak cross-contaminate antar reseller
            if (idReseller && t.idReseller) return String(t.idReseller) === String(idReseller);
            return t.pelanggan === namaPelanggan;
        })
        .reduce((s, t) => s + sisaTagihan(t), 0);
}

function renderReseller() {
    const tbody = document.querySelector('#tbl-reseller tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_RESELLER.length
        ? DATA_RESELLER.map((r, i) => {
            const terpakai = piutangBerjalan(r.nama, r.id);
            const limit    = Number(r.limitKredit || 0);
            const sisa     = limit - terpakai;
            const badge    = limit === 0 ? 'badge-gray' : (sisa <= 0 ? 'badge-red' : (sisa < limit * 0.2 ? 'badge-yellow' : 'badge-green'));
            return `<tr>
                <td>${escapeHtml(r.kode || r.id)}</td>
                <td><strong>${escapeHtml(r.nama)}</strong></td>
                <td>${escapeHtml(r.hp) || '—'}</td>
                <td>${Number(r.diskon || 0)}%</td>
                <td><span class="badge ${badge}">${formatRp(sisa)} / ${formatRp(limit)}</span></td>
                <td><span class="badge ${r.status === 'Aktif' ? 'badge-green' : 'badge-yellow'}">${escapeHtml(r.status)}</span></td>
                <td><div class="td-actions">
                    <button class="btn btn-info btn-sm" onclick="bukaEditReseller(${i})" aria-label="Edit ${escapeHtml(r.nama)}" title="Edit"><i data-lucide="pencil"></i></button>
                    <button class="btn btn-danger btn-sm" onclick="hapusReseller(${i})" aria-label="Hapus ${escapeHtml(r.nama)}" title="Hapus"><i data-lucide="trash-2"></i></button>
                </div></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(7, 'Belum ada reseller', 'Klik Tambah Reseller untuk memulai');
    const info = document.getElementById('info-reseller');
    if (info) info.textContent = `Menampilkan ${DATA_RESELLER.length} data`;
    lucide.createIcons();
}

function openTambahReseller() {
    editResellerIdx = -1;
    document.getElementById('modal-reseller-title').textContent = 'Tambah Reseller';
    document.getElementById('form-reseller').reset();
    document.getElementById('fr-kode').value   = nextKode('RSL', DATA_RESELLER, 'kode');
    document.getElementById('fr-diskon').value = 5;
    document.getElementById('fr-limit').value  = 5000000;
    document.getElementById('fr-status').value = 'Aktif';
    openModal('modal-reseller');
}

function bukaEditReseller(idx) {
    editResellerIdx = idx;
    const r = DATA_RESELLER[idx];
    document.getElementById('modal-reseller-title').textContent = 'Edit Reseller';
    document.getElementById('fr-kode').value   = r.kode || '';
    document.getElementById('fr-nama').value   = r.nama;
    document.getElementById('fr-hp').value     = r.hp || '';
    document.getElementById('fr-diskon').value = r.diskon || 0;
    document.getElementById('fr-limit').value  = r.limitKredit || 0;
    document.getElementById('fr-alamat').value = r.alamat || '';
    document.getElementById('fr-status').value = r.status;
    openModal('modal-reseller');
}

async function simpanReseller() {
    const nama = document.getElementById('fr-nama').value.trim();
    const hp   = document.getElementById('fr-hp').value.trim();
    if (!nama) { showToast('error', 'Nama reseller wajib diisi!'); return; }
    if (!hp)   { showToast('error', 'No. HP reseller wajib diisi!'); return; }

    const diskon = parseFloat(document.getElementById('fr-diskon').value) || 0;
    if (diskon < 0 || diskon > 50) { showToast('error', 'Diskon harus antara 0–50%!'); return; }

    const isEdit = editResellerIdx >= 0;
    const data = {
        id:          isEdit ? DATA_RESELLER[editResellerIdx].id : null,
        kode:        document.getElementById('fr-kode').value,
        nama, hp, diskon,
        limitKredit: parseInt(document.getElementById('fr-limit').value, 10) || 0,
        alamat:      document.getElementById('fr-alamat').value.trim(),
        status:      document.getElementById('fr-status').value,
    };

    const savedId = await dbUpsertReseller(data);
    if (savedId) data.id = savedId;
    else { data.id = data.id || idLokal('RSL'); showToast('warning', 'Tersimpan lokal, gagal sync ke server.'); }

    if (isEdit) DATA_RESELLER[editResellerIdx] = data;
    else DATA_RESELLER.push(data);

    closeModal('modal-reseller');
    renderReseller();
    showToast('success', isEdit ? 'Reseller berhasil diperbarui!' : 'Reseller baru berhasil ditambahkan!');
}

function hapusReseller(idx) {
    const r = DATA_RESELLER[idx];
    const terpakai = piutangBerjalan(r.nama, r.id);
    if (terpakai > 0) {
        showToast('error', `Reseller "${r.nama}" masih punya piutang berjalan ${formatRp(terpakai)}. Lunasi dulu sebelum dihapus.`);
        return;
    }
    showConfirm('Hapus Reseller', `Yakin ingin menghapus reseller "${r.nama}"?`, async () => {
        const ok = await dbDeleteReseller(r.id);
        if (!ok) { showToast('error', 'Gagal menghapus reseller dari database!'); return; }
        DATA_RESELLER.splice(idx, 1);
        renderReseller();
        showToast('success', 'Reseller berhasil dihapus.');
    });
}

// ── PEMBELIAN (PO) ───────────────────────────────────────────────────────────
let editPembelianIdx = -1;
let poItems = []; // item list sementara di form PO
let filteredPembelian = [];

function badgePembelian(status) {
    const map = { 'Lunas': 'badge-green', 'Hutang': 'badge-red', 'Pending': 'badge-yellow' };
    return map[status] || 'badge-gray';
}

function renderPembelian(data) {
    data = data || DATA_PEMBELIAN;
    filteredPembelian = data;
    const tbody = document.querySelector('#tbl-pembelian tbody');
    if (!tbody) return;
    tbody.innerHTML = data.length
        ? data.map(p => {
            const realIdx = DATA_PEMBELIAN.indexOf(p);
            const sisa = sisaTagihan(p);
            const tempoBadge = p.status === 'Hutang' && lewatJatuhTempo(p.jatuhTempo) ? ' badge-red' : '';
            return `<tr>
                <td><code class="inv-code">${escapeHtml(p.noFaktur)}</code></td>
                <td>${escapeHtml(p.supplier)}</td>
                <td>${formatTanggal(p.tanggal)}</td>
                <td>${p.jatuhTempo ? `<span class="badge${tempoBadge || ' badge-gray'}">${formatTanggal(p.jatuhTempo)}</span>` : '—'}</td>
                <td>${formatRp(p.total)}${sisa > 0 && sisa < p.total ? `<br><small style="color:var(--text-3)">sisa ${formatRp(sisa)}</small>` : ''}</td>
                <td><span class="badge ${badgePembelian(p.status)}">${escapeHtml(p.status)}</span></td>
                <td><div class="td-actions">
                    <button class="btn btn-info btn-sm" onclick="bukaEditPembelian(${realIdx})" aria-label="Edit ${escapeHtml(p.noFaktur)}" title="Edit"><i data-lucide="pencil"></i></button>
                    ${p.status === 'Hutang' ? `<button class="btn btn-primary btn-sm" onclick="openBayarHutang('${escapeHtml(p.noFaktur)}')">Bayar</button>` : ''}
                    <button class="btn btn-danger btn-sm" onclick="hapusPembelian(${realIdx})" aria-label="Hapus ${escapeHtml(p.noFaktur)}" title="Hapus"><i data-lucide="trash-2"></i></button>
                </div></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(7, DATA_PEMBELIAN.length === 0 ? 'Belum ada pembelian' : 'Tidak ada hasil filter',
                            DATA_PEMBELIAN.length === 0 ? 'Klik Buat PO Baru untuk memulai' : 'Coba ubah filter status');
    const info = document.getElementById('info-pembelian');
    if (info) info.textContent = `Menampilkan ${data.length} dari ${DATA_PEMBELIAN.length} data`;
    lucide.createIcons();
}

function filterPembelian() {
    const status = document.getElementById('filter-status-pembelian')?.value || '';
    renderPembelian(status ? DATA_PEMBELIAN.filter(p => p.status === status) : DATA_PEMBELIAN);
}

function populateProdukSelect(selectId, placeholder = 'Pilih Barang') {
    const sel = document.getElementById(selectId);
    if (!sel) return;
    const current = sel.value;
    sel.innerHTML = `<option value="">${placeholder}</option>` +
        DATA_BARANG.map(b => `<option value="${escapeHtml(b.nama)}">${escapeHtml(b.nama)} (stok ${b.stok})</option>`).join('');
    if (current) sel.value = current;
}

function hitungTotalPembelian() {
    // Total dihitung otomatis dari renderPoItems() saat item ditambahkan.
    // Fungsi ini tidak lagi auto-update total supaya tidak konflik dengan multi-item.
}

function togglePembelianHutang() {
    const wrap = document.getElementById('fp-tempo-wrap');
    const isHutang = document.getElementById('fp-bayar').value === 'Hutang';
    if (wrap) wrap.style.display = isHutang ? '' : 'none';
    const tempo = document.getElementById('fp-tempo');
    if (isHutang && tempo && !tempo.value) tempo.value = tambahHari(hariIni(), 30);
}

function isiHargaBeli() {
    const nama   = document.getElementById('fp-produk').value;
    const barang = DATA_BARANG.find(b => b.nama === nama);
    if (barang) document.getElementById('fp-harga').value = barang.hargaBeli;
}

function tambahItemPO() {
    const nama  = document.getElementById('fp-produk').value;
    const qty   = parseInt(document.getElementById('fp-qty').value, 10) || 0;
    const harga = parseInt(document.getElementById('fp-harga').value, 10) || 0;
    if (!nama)     { showToast('error', 'Pilih barang terlebih dahulu!'); return; }
    if (qty <= 0)  { showToast('error', 'Qty harus lebih dari 0!'); return; }

    const existing = poItems.findIndex(it => it.nama === nama);
    if (existing >= 0) {
        poItems[existing].qty += qty;
        poItems[existing].subtotal = poItems[existing].qty * poItems[existing].harga;
    } else {
        poItems.push({ nama, qty, harga, subtotal: qty * harga });
    }

    document.getElementById('fp-produk').value = '';
    document.getElementById('fp-qty').value    = 1;
    document.getElementById('fp-harga').value  = 0;
    renderPoItems();
}

function hapusItemPO(idx) {
    poItems.splice(idx, 1);
    renderPoItems();
}

function renderPoItems() {
    const tbody = document.querySelector('#tbl-po-items tbody');
    if (!tbody) return;
    if (poItems.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:var(--text-3);padding:12px">Belum ada item — tambahkan barang di atas</td></tr>';
        return;
    }
    tbody.innerHTML = poItems.map((it, i) => `<tr>
        <td>${escapeHtml(it.nama)}</td>
        <td>${it.qty}</td>
        <td>${formatRp(it.harga)}</td>
        <td><strong>${formatRp(it.subtotal)}</strong></td>
        <td><button type="button" class="btn btn-danger btn-sm" onclick="hapusItemPO(${i})"><i data-lucide="trash-2"></i></button></td>
    </tr>`).join('');
    document.getElementById('fp-total').value = poItems.reduce((s, it) => s + it.subtotal, 0);
    lucide.createIcons();
}

function openTambahPembelian() {
    editPembelianIdx = -1;
    poItems = [];
    document.getElementById('modal-pembelian-title').textContent = 'Buat Purchase Order';
    document.getElementById('form-pembelian').reset();
    document.getElementById('fp-no').value      = nextKode('PO', DATA_PEMBELIAN, 'noFaktur');
    document.getElementById('fp-tanggal').value = hariIni();
    document.getElementById('fp-qty').value     = 1;
    document.getElementById('fp-harga').value   = 0;
    document.getElementById('fp-total').value   = 0;
    document.getElementById('fp-bayar').value   = 'Lunas';
    populateSupplierSelects();
    populateProdukSelect('fp-produk');
    togglePembelianHutang();
    renderPoItems();
    openModal('modal-pembelian');
}

function bukaEditPembelian(idx) {
    editPembelianIdx = idx;
    const p = DATA_PEMBELIAN[idx];
    document.getElementById('modal-pembelian-title').textContent = 'Edit Purchase Order';
    populateSupplierSelects();
    populateProdukSelect('fp-produk');
    document.getElementById('fp-no').value      = p.noFaktur;
    document.getElementById('fp-tanggal').value = p.tanggal || hariIni();
    document.getElementById('fp-total').value   = p.total;
    document.getElementById('fp-bayar').value   = p.status === 'Hutang' ? 'Hutang' : 'Lunas';
    document.getElementById('fp-tempo').value   = p.jatuhTempo || '';
    document.getElementById('fp-ket').value     = p.keterangan || '';
    // Qty/produk tidak diedit ulang supaya stok tidak dobel dihitung.
    document.getElementById('fp-qty').value     = 0;
    document.getElementById('fp-harga').value   = 0;
    document.getElementById('fp-produk').value  = '';
    const sup = document.getElementById('po-supplier');
    const supEntry = DATA_SUPPLIER.find(s => s.nama === p.supplier);
    if (sup && supEntry) sup.value = supEntry.id;
    // Tampilkan item yang sudah ada (readonly saat edit)
    poItems = (p.items || []).map(it => ({ ...it, subtotal: it.qty * (it.harga || 0) }));
    renderPoItems();
    togglePembelianHutang();
    openModal('modal-pembelian');
}

async function simpanPembelian() {
    const supplierId = document.getElementById('po-supplier').value;
    const total      = parseInt(document.getElementById('fp-total').value, 10) || 0;
    const bayar      = document.getElementById('fp-bayar').value;
    const tanggal    = document.getElementById('fp-tanggal').value || hariIni();
    const produk     = document.getElementById('fp-produk').value;
    const qty        = parseInt(document.getElementById('fp-qty').value, 10) || 0;

    if (!supplierId) { showToast('error', 'Pilih supplier terlebih dahulu!'); return; }
    if (total <= 0)  { showToast('error', 'Total pembelian harus lebih dari 0!'); return; }

    const isEdit = editPembelianIdx >= 0;
    // Validasi item: minimal ada 1 di list, atau barang langsung dipilih di form
    if (!isEdit && poItems.length === 0 && !produk) {
        showToast('error', 'Tambahkan minimal 1 barang ke PO terlebih dahulu!');
        return;
    }

    let jatuhTempo = null;
    if (bayar === 'Hutang') {
        jatuhTempo = document.getElementById('fp-tempo').value;
        if (!jatuhTempo) { showToast('error', 'Pembelian hutang wajib punya tanggal jatuh tempo!'); return; }
        if (jatuhTempo < tanggal) { showToast('error', 'Jatuh tempo tidak boleh sebelum tanggal PO!'); return; }
    }

    const supplier = DATA_SUPPLIER.find(s => String(s.id) === String(supplierId));
    const terbayarLama = isEdit ? Number(DATA_PEMBELIAN[editPembelianIdx].terbayar || 0) : 0;
    if (terbayarLama > total) {
        showToast('error', `Total tidak boleh lebih kecil dari cicilan yang sudah dibayar (${formatRp(terbayarLama)}).`);
        return;
    }

    const data = {
        id:         isEdit ? DATA_PEMBELIAN[editPembelianIdx].id : null,
        noFaktur:   document.getElementById('fp-no').value,
        supplier:   supplier ? supplier.nama : '—',
        tanggal,
        jatuhTempo: jatuhTempo || '',
        total,
        terbayar:   bayar === 'Hutang' ? terbayarLama : total,
        status:     bayar === 'Hutang' ? (terbayarLama >= total ? 'Lunas' : 'Hutang') : 'Lunas',
        keterangan: document.getElementById('fp-ket').value.trim(),
        items: isEdit ? (DATA_PEMBELIAN[editPembelianIdx]?.items ?? []) : [...poItems],
    };

    // Jika user mengisi barang tapi belum klik "Tambah Item", otomatis tambahkan
    if (!isEdit && poItems.length === 0 && produk && qty > 0) {
        const harga = parseInt(document.getElementById('fp-harga').value, 10) || 0;
        data.items = [{ nama: produk, qty, harga, subtotal: qty * harga }];
    }

    if (!isEdit && data.items.length === 0) {
        showToast('error', 'Tambahkan minimal 1 barang ke PO!');
        return;
    }

    const savedId = await dbUpsertPembelian(data);
    if (savedId) data.id = savedId;
    else { data.id = data.id || idLokal('PB'); showToast('warning', 'Tersimpan lokal, gagal sync ke server.'); }

    if (isEdit) DATA_PEMBELIAN[editPembelianIdx] = data;
    else DATA_PEMBELIAN.unshift(data);

    // Barang masuk & simpan item hanya untuk PO baru.
    if (!isEdit) {
        // Simpan item ke tabel pembelian_item di DB
        if (data.id && !String(data.id).startsWith('PB-LOKAL')) {
            await dbInsertPembelianItems(data.id, data.items);
        }
        // Update stok untuk setiap item
        for (const it of data.items) {
            const ok = await terapkanStok(it.nama, it.qty);
            if (!ok) showToast('warning', `Stok "${it.nama}" gagal diperbarui.`);
        }
        // Kas keluar untuk PO Lunas dicatat otomatis oleh trigger DB
        // fn_catat_kas_pembelian saat baris `pembelian` di-INSERT — lihat
        // supabase/migration_kas_shift_realtime.sql. Jangan catat manual lagi.
    }

    closeModal('modal-pembelian');
    renderPembelian();
    renderHutang();
    renderKas();
    renderLaporanPembelian();
    renderLaporanHutang();
    updateDashboard();
    showToast('success', isEdit ? 'PO berhasil diperbarui!'
        : (bayar === 'Hutang' ? 'PO tersimpan. Tagihan masuk ke halaman Pelunasan Hutang.' : 'PO berhasil dibuat dan stok bertambah!'));
}

function hapusPembelian(idx) {
    const p = DATA_PEMBELIAN[idx];
    const sudahDibayar = Number(p.terbayar || 0);
    const pesan = sudahDibayar > 0
        ? `PO "${p.noFaktur}" sudah dibayar ${formatRp(sudahDibayar)}. Riwayat pembayarannya ikut terhapus. Lanjutkan?`
        : `Yakin ingin menghapus PO "${p.noFaktur}"?`;
    showConfirm('Hapus Pembelian', pesan, async () => {
        const ok = await dbDeletePembelian(p.id);
        if (!ok) { showToast('error', 'Gagal menghapus PO dari database!'); return; }
        DATA_PEMBELIAN.splice(idx, 1);
        // Kembalikan stok dari item PO (ON DELETE CASCADE hapus pembelian_item otomatis di DB)
        const itemList = p.items || [];
        if (itemList.length > 0) {
            for (const it of itemList) {
                const barang = DATA_BARANG.find(b => b.nama === it.nama);
                if (barang) {
                    barang.stok = Math.max(0, barang.stok - it.qty);
                    await dbUpdateStok(barang.id, barang.stok);
                }
            }
            renderBarang();
        } else {
            showToast('info', 'PO ini tidak menyimpan detail item — sesuaikan stok manual jika perlu.');
        }
        renderPembelian();
        renderHutang();
        renderLaporanPembelian();
        renderLaporanHutang();
        updateDashboard();
        showToast('success', 'PO berhasil dihapus.');
    });
}

// ── RETUR PEMBELIAN ──────────────────────────────────────────────────────────
function badgeRetur(status) {
    const map = { 'Selesai': 'badge-green', 'Diproses': 'badge-yellow', 'Ditolak': 'badge-red' };
    return map[status] || 'badge-gray';
}

function renderReturBeli() {
    const tbody = document.querySelector('#tbl-retur-beli tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_RETUR_BELI.length
        ? DATA_RETUR_BELI.map((r, i) => `
        <tr>
            <td><code class="inv-code">${escapeHtml(r.id)}</code></td>
            <td>${escapeHtml(r.faktur)}</td>
            <td>${escapeHtml(r.supplier)}</td>
            <td>${formatTanggal(r.tanggal)}</td>
            <td>${formatRp(r.total)}</td>
            <td>${escapeHtml(r.alasan) || '—'}</td>
            <td><span class="badge ${badgeRetur(r.status)}">${escapeHtml(r.status)}</span></td>
            <td><div class="td-actions">
                ${r.status === 'Diproses' ? `<button class="btn btn-primary btn-sm" onclick="selesaikanReturBeli(${i})">Selesaikan</button>` : ''}
            </div></td>
        </tr>`).join('')
        : tableEmptyHTML(8, 'Belum ada retur pembelian', 'Klik Buat Retur untuk memulai');
    const info = document.getElementById('info-retur-beli');
    if (info) info.textContent = `Menampilkan ${DATA_RETUR_BELI.length} data`;
    lucide.createIcons();
}

function populatePoSelect() {
    const sel = document.getElementById('frb-po');
    if (!sel) return;
    sel.innerHTML = '<option value="">Pilih PO pembelian</option>' +
        DATA_PEMBELIAN.map(p => `<option value="${escapeHtml(p.noFaktur)}">${escapeHtml(p.noFaktur)} — ${escapeHtml(p.supplier)} (${formatRp(p.total)})</option>`).join('');
}

function isiMaxReturBeli() {
    const noPo = document.getElementById('frb-po').value;
    const po   = DATA_PEMBELIAN.find(p => p.noFaktur === noPo);
    const info = document.getElementById('frb-max');
    if (!po) { if (info) info.textContent = ''; return; }
    const sudahDiretur = DATA_RETUR_BELI
        .filter(r => r.faktur === noPo && r.status !== 'Ditolak')
        .reduce((s, r) => s + Number(r.total || 0), 0);
    const sisa = Math.max(0, po.total - sudahDiretur);
    if (info) info.textContent = `Maksimal retur: ${formatRp(sisa)}`;
    const totalInput = document.getElementById('frb-total');
    if (totalInput) totalInput.max = sisa;
}

function openTambahReturBeli() {
    document.getElementById('form-retur-beli').reset();
    document.getElementById('frb-tanggal').value = hariIni();
    populatePoSelect();
    populateProdukSelect('frb-produk', '— Tidak mengurangi stok —');
    document.getElementById('frb-max').textContent = '';
    openModal('modal-retur-beli');
}

async function simpanReturBeli() {
    const noPo   = document.getElementById('frb-po').value;
    const total  = parseInt(document.getElementById('frb-total').value, 10) || 0;
    const produk = document.getElementById('frb-produk').value;
    const qty    = parseInt(document.getElementById('frb-qty').value, 10) || 0;

    if (!noPo)      { showToast('error', 'Pilih PO yang akan diretur!'); return; }
    if (total <= 0) { showToast('error', 'Total retur harus lebih dari 0!'); return; }

    const po = DATA_PEMBELIAN.find(p => p.noFaktur === noPo);
    const sudahDiretur = DATA_RETUR_BELI
        .filter(r => r.faktur === noPo && r.status !== 'Ditolak')
        .reduce((s, r) => s + Number(r.total || 0), 0);
    if (po && total + sudahDiretur > po.total) {
        showToast('error', `Total retur melebihi nilai PO. Sisa yang bisa diretur: ${formatRp(po.total - sudahDiretur)}.`);
        return;
    }
    if (produk && qty > 0) {
        const barang = DATA_BARANG.find(b => b.nama === produk);
        if (barang && qty > barang.stok) {
            showToast('error', `Stok "${produk}" cuma ${barang.stok}, tidak bisa retur ${qty}.`);
            return;
        }
    }

    const data = {
        id:       nextKode('RB', DATA_RETUR_BELI),
        faktur:   noPo,
        supplier: po ? po.supplier : '—',
        tanggal:  document.getElementById('frb-tanggal').value || hariIni(),
        total,
        alasan:   document.getElementById('frb-alasan').value,
        status:   'Diproses',
        produk, qty,
    };
    if (document.getElementById('frb-ket').value.trim()) {
        data.alasan += ' — ' + document.getElementById('frb-ket').value.trim();
    }

    const savedId = await dbUpsertReturBeli(data);
    if (!savedId) showToast('warning', 'Tersimpan lokal, gagal sync ke server.');
    DATA_RETUR_BELI.unshift(data);

    // Barang keluar ke supplier → stok berkurang.
    if (produk && qty > 0) await terapkanStok(produk, -qty);

    closeModal('modal-retur-beli');
    renderReturBeli();
    showToast('success', 'Retur pembelian berhasil dicatat.');
}

function selesaikanReturBeli(idx) {
    const r = DATA_RETUR_BELI[idx];
    showConfirm('Selesaikan Retur', `Tandai retur "${r.id}" sebagai selesai?`, async () => {
        r.status = 'Selesai';
        await dbUpsertReturBeli(r);
        renderReturBeli();
        showToast('success', 'Retur pembelian selesai.');
    }, { type: 'primary', icon: 'check-circle', btnText: 'Ya, Selesaikan' });
}

// ── RETUR PENJUALAN ──────────────────────────────────────────────────────────
function renderReturJual() {
    const tbody = document.querySelector('#tbl-retur-jual tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_RETUR_JUAL.length
        ? DATA_RETUR_JUAL.map((r, i) => `
        <tr>
            <td><code class="inv-code">${escapeHtml(r.id)}</code></td>
            <td>${escapeHtml(r.faktur)}</td>
            <td>${escapeHtml(r.pelanggan)}</td>
            <td>${formatTanggal(r.tanggal)}</td>
            <td>${formatRp(r.total)}</td>
            <td>${escapeHtml(r.alasan) || '—'}</td>
            <td><span class="badge ${badgeRetur(r.status)}">${escapeHtml(r.status)}</span></td>
            <td><div class="td-actions">
                ${r.status === 'Diproses' ? `<button class="btn btn-primary btn-sm" onclick="selesaikanReturJual(${i})">Selesaikan</button>` : ''}
            </div></td>
        </tr>`).join('')
        : tableEmptyHTML(8, 'Belum ada retur penjualan', 'Klik Buat Retur untuk memulai');
    const info = document.getElementById('info-retur-jual');
    if (info) info.textContent = `Menampilkan ${DATA_RETUR_JUAL.length} data`;
    lucide.createIcons();
}

function populateFakturSelect() {
    const sel = document.getElementById('frj-faktur');
    if (!sel) return;
    sel.innerHTML = '<option value="">Pilih faktur penjualan</option>' +
        DATA_PENJUALAN.map(t => `<option value="${escapeHtml(t.id)}">#${escapeHtml(t.id)} — ${escapeHtml(t.pelanggan)} (${formatRp(t.total)})</option>`).join('');
}

function isiMaxReturJual() {
    const noFaktur = document.getElementById('frj-faktur').value;
    const trx  = DATA_PENJUALAN.find(t => t.id === noFaktur);
    const info = document.getElementById('frj-max');
    if (!trx) { if (info) info.textContent = ''; return; }
    const sudahDiretur = DATA_RETUR_JUAL
        .filter(r => r.faktur === noFaktur && r.status !== 'Ditolak')
        .reduce((s, r) => s + Number(r.total || 0), 0);
    const sisa = Math.max(0, trx.total - sudahDiretur);
    if (info) info.textContent = `Maksimal retur: ${formatRp(sisa)}`;
    const totalInput = document.getElementById('frj-total');
    if (totalInput) totalInput.max = sisa;
}

function openTambahReturJual() {
    document.getElementById('form-retur-jual').reset();
    document.getElementById('frj-tanggal').value = hariIni();
    populateFakturSelect();
    populateProdukSelect('frj-produk', '— Tidak menambah stok —');
    document.getElementById('frj-max').textContent = '';
    openModal('modal-retur-jual');
}

async function simpanReturJual() {
    const noFaktur = document.getElementById('frj-faktur').value;
    const total    = parseInt(document.getElementById('frj-total').value, 10) || 0;
    const produk   = document.getElementById('frj-produk').value;
    const qty      = parseInt(document.getElementById('frj-qty').value, 10) || 0;

    if (!noFaktur)  { showToast('error', 'Pilih faktur penjualan yang diretur!'); return; }
    if (total <= 0) { showToast('error', 'Total retur harus lebih dari 0!'); return; }

    const trx = DATA_PENJUALAN.find(t => t.id === noFaktur);
    const sudahDiretur = DATA_RETUR_JUAL
        .filter(r => r.faktur === noFaktur && r.status !== 'Ditolak')
        .reduce((s, r) => s + Number(r.total || 0), 0);
    if (trx && total + sudahDiretur > trx.total) {
        showToast('error', `Total retur melebihi nilai transaksi. Sisa yang bisa diretur: ${formatRp(trx.total - sudahDiretur)}.`);
        return;
    }

    const data = {
        id:        nextKode('RJ', DATA_RETUR_JUAL),
        faktur:    noFaktur,
        pelanggan: trx ? trx.pelanggan : '—',
        tanggal:   document.getElementById('frj-tanggal').value || hariIni(),
        total,
        alasan:    document.getElementById('frj-alasan').value,
        status:    'Diproses',
        produk, qty,
    };
    if (document.getElementById('frj-ket').value.trim()) {
        data.alasan += ' — ' + document.getElementById('frj-ket').value.trim();
    }

    const savedId = await dbUpsertReturJual(data);
    if (!savedId) showToast('warning', 'Tersimpan lokal, gagal sync ke server.');
    DATA_RETUR_JUAL.unshift(data);

    // Barang kembali dari pelanggan → stok bertambah.
    if (produk && qty > 0) await terapkanStok(produk, qty);

    closeModal('modal-retur-jual');
    renderReturJual();
    showToast('success', 'Retur penjualan berhasil dicatat.');
}

function selesaikanReturJual(idx) {
    const r = DATA_RETUR_JUAL[idx];
    showConfirm('Selesaikan Retur', `Tandai retur "${r.id}" sebagai selesai?`, async () => {
        r.status = 'Selesai';
        await dbUpsertReturJual(r);
        renderReturJual();
        showToast('success', 'Retur penjualan selesai.');
    }, { type: 'primary', icon: 'check-circle', btnText: 'Ya, Selesaikan' });
}

// ── PELUNASAN PIUTANG ────────────────────────────────────────────────────────
// Piutang tidak punya tabel sendiri: sumbernya transaksi berstatus 'Piutang'.
function daftarPiutang() {
    return DATA_PENJUALAN.filter(t => t.status === 'Piutang');
}

function statusTagihan(item) {
    const sisa = sisaTagihan(item);
    if (sisa <= 0) return { teks: 'Lunas', badge: 'badge-green' };
    if (lewatJatuhTempo(item.jatuhTempo)) return { teks: 'Jatuh Tempo', badge: 'badge-red' };
    if (Number(item.terbayar || 0) > 0) return { teks: 'Sebagian', badge: 'badge-blue' };
    return { teks: 'Belum Lunas', badge: 'badge-yellow' };
}

function renderPiutang() {
    const tbody = document.querySelector('#tbl-piutang tbody');
    if (!tbody) return;
    const data = daftarPiutang();
    tbody.innerHTML = data.length
        ? data.map(t => {
            const st = statusTagihan(t);
            return `<tr>
                <td><code class="inv-code">#${escapeHtml(t.id)}</code></td>
                <td>${escapeHtml(t.pelanggan)}</td>
                <td>${formatTanggal(t.tanggal)}</td>
                <td>${t.jatuhTempo ? formatTanggal(t.jatuhTempo) : '—'}</td>
                <td>${formatRp(t.total)}</td>
                <td>${formatRp(t.terbayar || 0)}</td>
                <td><strong>${formatRp(sisaTagihan(t))}</strong></td>
                <td><span class="badge ${st.badge}">${st.teks}</span></td>
                <td><div class="td-actions">
                    <button class="btn btn-primary btn-sm" onclick="openBayarPiutang('${escapeHtml(t.id)}')">Bayar</button>
                    <button class="btn btn-info btn-sm" onclick="lunasiPiutang('${escapeHtml(t.id)}')" title="Lunasi penuh"><i data-lucide="check-check"></i></button>
                </div></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(9, 'Tidak ada piutang aktif', 'Semua tagihan pelanggan sudah lunas');
    const info = document.getElementById('info-piutang');
    if (info) info.textContent = `Menampilkan ${data.length} tagihan`;
    lucide.createIcons();
}

function populatePiutangSelect(selectedId) {
    const sel = document.getElementById('fbp-faktur');
    if (!sel) return;
    const data = daftarPiutang();
    sel.innerHTML = data.length
        ? '<option value="">Pilih faktur</option>' + data.map(t =>
            `<option value="${escapeHtml(t.id)}">#${escapeHtml(t.id)} — ${escapeHtml(t.pelanggan)} (sisa ${formatRp(sisaTagihan(t))})</option>`).join('')
        : '<option value="">Tidak ada piutang aktif</option>';
    if (selectedId) sel.value = selectedId;
}

function isiSisaPiutang() {
    const id  = document.getElementById('fbp-faktur').value;
    const trx = DATA_PENJUALAN.find(t => t.id === id);
    const sisa = trx ? sisaTagihan(trx) : 0;
    document.getElementById('fbp-total').value = trx ? formatRp(trx.total) : '';
    document.getElementById('fbp-sisa').value  = trx ? formatRp(sisa) : '';
    const jumlah = document.getElementById('fbp-jumlah');
    jumlah.max = sisa;
    jumlah.value = sisa;
}

function openBayarPiutang(id) {
    document.getElementById('form-bayar-piutang').reset();
    populatePiutangSelect(id);
    document.getElementById('fbp-tanggal').value = hariIni();
    isiSisaPiutang();
    openModal('modal-bayar-piutang');
}

async function simpanBayarPiutang() {
    const id      = document.getElementById('fbp-faktur').value;
    const nominal = parseInt(document.getElementById('fbp-jumlah').value, 10) || 0;
    const metode  = document.getElementById('fbp-metode').value;
    const tanggal = document.getElementById('fbp-tanggal').value || hariIni();

    if (!id)         { showToast('error', 'Pilih faktur piutang terlebih dahulu!'); return; }
    const trx = DATA_PENJUALAN.find(t => t.id === id);
    if (!trx)        { showToast('error', 'Data piutang tidak ditemukan.'); return; }
    if (nominal <= 0){ showToast('error', 'Jumlah bayar harus lebih dari 0!'); return; }

    const sisa = sisaTagihan(trx);
    if (nominal > sisa) {
        showToast('error', `Jumlah bayar melebihi sisa tagihan (${formatRp(sisa)}).`);
        return;
    }

    trx.terbayar = Number(trx.terbayar || 0) + nominal;
    const lunas = sisaTagihan(trx) <= 0;
    if (lunas) trx.status = 'Lunas';

    const ok = await dbCatatPembayaran('piutang',
        { id: trx.dbId ?? trx.id, noReferensi: trx.id, terbayar: trx.terbayar, status: trx.status },
        nominal, metode, tanggal);
    if (!ok) showToast('warning', 'Pembayaran tercatat lokal, gagal sync ke server.');

    DATA_PEMBAYARAN.unshift({ jenis: 'piutang', ref: trx.id, nominal, metode, tanggal });

    // Pelunasan piutang tunai dicatat otomatis sebagai kas masuk oleh RPC
    // catat_cicilan (server-side) — lihat supabase/migration_kas_shift_realtime.sql.

    closeModal('modal-bayar-piutang');
    renderPiutang();
    renderPenjualan();
    renderReseller();
    renderLaporanPenjualan();
    renderLaporanPiutang();
    renderKas();
    updateDashboard();
    showToast('success', lunas
        ? `Piutang #${trx.id} lunas!`
        : `Cicilan ${formatRp(nominal)} tercatat. Sisa ${formatRp(sisaTagihan(trx))}.`);
}

// ── PELUNASAN HUTANG ─────────────────────────────────────────────────────────
function daftarHutang() {
    return DATA_PEMBELIAN.filter(p => p.status === 'Hutang');
}

function renderHutang() {
    const tbody = document.querySelector('#tbl-hutang tbody');
    if (!tbody) return;
    const data = daftarHutang();
    tbody.innerHTML = data.length
        ? data.map(p => {
            const st = statusTagihan(p);
            return `<tr>
                <td><code class="inv-code">${escapeHtml(p.noFaktur)}</code></td>
                <td>${escapeHtml(p.supplier)}</td>
                <td>${formatTanggal(p.tanggal)}</td>
                <td>${p.jatuhTempo ? formatTanggal(p.jatuhTempo) : '—'}</td>
                <td>${formatRp(p.total)}</td>
                <td>${formatRp(p.terbayar || 0)}</td>
                <td><strong>${formatRp(sisaTagihan(p))}</strong></td>
                <td><span class="badge ${st.badge}">${st.teks}</span></td>
                <td><div class="td-actions">
                    <button class="btn btn-primary btn-sm" onclick="openBayarHutang('${escapeHtml(p.noFaktur)}')">Bayar</button>
                </div></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(9, 'Tidak ada hutang aktif', 'Semua tagihan supplier sudah lunas');
    const info = document.getElementById('info-hutang');
    if (info) info.textContent = `Menampilkan ${data.length} tagihan`;
    lucide.createIcons();
}

function populateHutangSelect(selectedNo) {
    const sel = document.getElementById('fbh-po');
    if (!sel) return;
    const data = daftarHutang();
    sel.innerHTML = data.length
        ? '<option value="">Pilih PO</option>' + data.map(p =>
            `<option value="${escapeHtml(p.noFaktur)}">${escapeHtml(p.noFaktur)} — ${escapeHtml(p.supplier)} (sisa ${formatRp(sisaTagihan(p))})</option>`).join('')
        : '<option value="">Tidak ada hutang aktif</option>';
    if (selectedNo) sel.value = selectedNo;
}

function isiSisaHutang() {
    const no = document.getElementById('fbh-po').value;
    const po = DATA_PEMBELIAN.find(p => p.noFaktur === no);
    const sisa = po ? sisaTagihan(po) : 0;
    document.getElementById('fbh-total').value = po ? formatRp(po.total) : '';
    document.getElementById('fbh-sisa').value  = po ? formatRp(sisa) : '';
    const jumlah = document.getElementById('fbh-jumlah');
    jumlah.max = sisa;
    jumlah.value = sisa;
}

function openBayarHutang(noFaktur) {
    document.getElementById('form-bayar-hutang').reset();
    populateHutangSelect(noFaktur);
    document.getElementById('fbh-tanggal').value = hariIni();
    isiSisaHutang();
    openModal('modal-bayar-hutang');
}

async function simpanBayarHutang() {
    const no      = document.getElementById('fbh-po').value;
    const nominal = parseInt(document.getElementById('fbh-jumlah').value, 10) || 0;
    const metode  = document.getElementById('fbh-metode').value;
    const tanggal = document.getElementById('fbh-tanggal').value || hariIni();

    if (!no)          { showToast('error', 'Pilih PO hutang terlebih dahulu!'); return; }
    const po = DATA_PEMBELIAN.find(p => p.noFaktur === no);
    if (!po)          { showToast('error', 'Data hutang tidak ditemukan.'); return; }
    if (nominal <= 0) { showToast('error', 'Jumlah bayar harus lebih dari 0!'); return; }

    const sisa = sisaTagihan(po);
    if (nominal > sisa) {
        showToast('error', `Jumlah bayar melebihi sisa tagihan (${formatRp(sisa)}).`);
        return;
    }

    po.terbayar = Number(po.terbayar || 0) + nominal;
    const lunas = sisaTagihan(po) <= 0;
    if (lunas) po.status = 'Lunas';

    const ok = await dbCatatPembayaran('hutang',
        { id: po.id, noReferensi: po.noFaktur, terbayar: po.terbayar, status: po.status },
        nominal, metode, tanggal);
    if (!ok) showToast('warning', 'Pembayaran tercatat lokal, gagal sync ke server.');

    DATA_PEMBAYARAN.unshift({ jenis: 'hutang', ref: po.noFaktur, nominal, metode, tanggal });

    // Pembayaran hutang tunai dicatat otomatis sebagai kas keluar oleh RPC
    // catat_cicilan (server-side) — lihat supabase/migration_kas_shift_realtime.sql.

    closeModal('modal-bayar-hutang');
    renderHutang();
    renderPembelian();
    renderLaporanPembelian();
    renderLaporanHutang();
    renderKas();
    updateDashboard();
    showToast('success', lunas
        ? `Hutang ${po.noFaktur} lunas!`
        : `Cicilan ${formatRp(nominal)} tercatat. Sisa ${formatRp(sisaTagihan(po))}.`);
}

// ── KAS KASIR ────────────────────────────────────────────────────────────────
// Saldo dihitung berjalan (running balance) urut waktu, bukan disimpan per baris,
// supaya tetap benar kalau ada mutasi yang dihapus atau disisipkan mundur.
function kasTerurut(list) {
    return [...list].sort((a, b) => {
        const ka = `${a.tanggal || ''} ${a.jam || ''}`;
        const kb = `${b.tanggal || ''} ${b.jam || ''}`;
        return ka < kb ? -1 : ka > kb ? 1 : 0;
    });
}

function kasDenganSaldo(list) {
    let saldo = 0;
    return kasTerurut(list).map(k => {
        saldo += k.tipe === 'masuk' ? Number(k.nominal || 0) : -Number(k.nominal || 0);
        return { ...k, saldo };
    });
}

function renderKas() {
    const tbody = document.querySelector('#tbl-kas tbody');
    if (!tbody) return;

    const filterKasir = document.getElementById('filter-kas-kasir')?.value || '';
    const sumber = filterKasir ? DATA_KAS.filter(k => k.kasir === filterKasir) : DATA_KAS;
    const rows = kasDenganSaldo(sumber).reverse(); // terbaru di atas

    tbody.innerHTML = rows.length
        ? rows.map(k => `
        <tr>
            <td>${formatTanggal(k.tanggal)}${k.jam ? ` <small style="color:var(--text-3)">${escapeHtml(k.jam)}</small>` : ''}</td>
            <td>${escapeHtml(k.kasir) || '—'}</td>
            <td>${escapeHtml(k.keterangan)}</td>
            <td>${k.tipe === 'masuk' ? formatRp(k.nominal) : '—'}</td>
            <td>${k.tipe === 'keluar' ? formatRp(k.nominal) : '—'}</td>
            <td><strong>${formatRp(k.saldo)}</strong></td>
            <td><div class="td-actions">
                <button class="btn btn-danger btn-sm" onclick="hapusKas('${escapeHtml(k.id)}')" aria-label="Hapus mutasi" title="Hapus"><i data-lucide="trash-2"></i></button>
            </div></td>
        </tr>`).join('')
        : tableEmptyHTML(7, 'Belum ada mutasi kas', 'Klik Catat Kas untuk mencatat mutasi pertama');

    const masuk  = sumber.filter(k => k.tipe === 'masuk').reduce((s, k) => s + Number(k.nominal || 0), 0);
    const keluar = sumber.filter(k => k.tipe === 'keluar').reduce((s, k) => s + Number(k.nominal || 0), 0);
    const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setEl('kas-total-masuk',  formatRp(masuk));
    setEl('kas-total-keluar', formatRp(keluar));
    setEl('kas-saldo',        formatRp(masuk - keluar));
    setEl('info-kas', `Menampilkan ${rows.length} dari ${DATA_KAS.length} mutasi`);
    lucide.createIcons();
}

function populateKasirSelects() {
    const kasirList = DATA_USERS.filter(u => u.status === 'Aktif').map(u => u.nama);
    const namaKasir = [...new Set([...kasirList, ...DATA_KAS.map(k => k.kasir)])].filter(Boolean).sort();

    const isiSelect = (id, labelSemua) => {
        const sel = document.getElementById(id);
        if (!sel) return;
        const current = sel.value;
        sel.innerHTML = (labelSemua ? `<option value="">${labelSemua}</option>` : '') +
            namaKasir.map(n => `<option value="${escapeHtml(n)}">${escapeHtml(n)}</option>`).join('');
        if (current) sel.value = current;
    };
    isiSelect('filter-kas-kasir', 'Semua Kasir');
    isiSelect('lap-kas-kasir', 'Semua Kasir');
    isiSelect('fkas-kasir', null);
    isiSelect('fsh-kasir', null);

    const fk = document.getElementById('fkas-kasir');
    if (fk && !fk.value) fk.value = namaPetugas();

    // Petugas opname memakai daftar user yang sama.
    const fo = document.getElementById('fo-petugas');
    if (fo) {
        const cur = fo.value;
        fo.innerHTML = namaKasir.map(n => `<option value="${escapeHtml(n)}">${escapeHtml(n)}</option>`).join('');
        fo.value = cur || namaPetugas();
    }
}

function openTambahKas() {
    document.getElementById('form-kas').reset();
    document.getElementById('fkas-tipe').value    = 'masuk';
    document.getElementById('fkas-tanggal').value = hariIni();
    populateKasirSelects();
    openModal('modal-kas');
}

async function simpanKas() {
    const nominal = parseInt(document.getElementById('fkas-nominal').value, 10) || 0;
    const ket     = document.getElementById('fkas-ket').value.trim();
    if (nominal <= 0) { showToast('error', 'Nominal harus lebih dari 0!'); return; }
    if (!ket)         { showToast('error', 'Keterangan wajib diisi!'); return; }

    const tipe = document.getElementById('fkas-tipe').value;
    const data = {
        id:         'KAS-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
        keterangan: ket,
        tanggal:    document.getElementById('fkas-tanggal').value || hariIni(),
        jam:        new Date().toTimeString().slice(0, 5),
        nominal,
        tipe,
        kasir:      document.getElementById('fkas-kasir').value || namaPetugas(),
    };

    if (tipe === 'keluar') {
        const saldo = DATA_KAS.reduce((s, k) => s + (k.tipe === 'masuk' ? k.nominal : -k.nominal), 0);
        if (nominal > saldo) {
            showToast('error', `Kas keluar melebihi saldo tersedia (${formatRp(saldo)}).`);
            return;
        }
    }

    const savedId = await dbInsertKas(data);
    if (savedId) data.id = savedId;
    else showToast('warning', 'Tersimpan lokal, gagal sync ke server.');  // id lokal sudah dibuat di atas

    DATA_KAS.push(data);
    closeModal('modal-kas');
    populateKasirSelects();
    renderKas();
    renderLaporanKas();
    showToast('success', `Kas ${tipe} ${formatRp(nominal)} berhasil dicatat.`);
}

// Dipakai modul lain (pelunasan piutang/hutang tunai) untuk mencatat kas otomatis.
async function catatKasOtomatis(tipe, nominal, keterangan, tanggal) {
    const data = {
        id: 'KAS-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
        keterangan, tipe, nominal,
        tanggal: tanggal || hariIni(),
        jam: new Date().toTimeString().slice(0, 5),
        kasir: namaPetugas(),
    };
    const savedId = await dbInsertKas(data);
    if (savedId) data.id = savedId;
    DATA_KAS.push(data);
    renderLaporanKas();
}

function hapusKas(id) {
    const idx = DATA_KAS.findIndex(k => String(k.id) === String(id));
    if (idx === -1) return;
    const k = DATA_KAS[idx];
    showConfirm('Hapus Mutasi Kas', `Yakin ingin menghapus "${k.keterangan}" senilai ${formatRp(k.nominal)}?`, async () => {
        const ok = await dbDeleteKas(k.id);
        if (!ok) { showToast('error', 'Gagal menghapus mutasi kas!'); return; }
        DATA_KAS.splice(idx, 1);
        renderKas();
        renderLaporanKas();
        showToast('success', 'Mutasi kas berhasil dihapus.');
    });
}

// ── STOCK OPNAME ─────────────────────────────────────────────────────────────
function renderOpname() {
    const tbody = document.querySelector('#tbl-opname tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_OPNAME.length
        ? DATA_OPNAME.map((o, i) => {
            const selisihBadge = o.selisih === 0 ? 'badge-gray' : (o.selisih < 0 ? 'badge-red' : 'badge-green');
            return `<tr>
                <td><code class="inv-code">${escapeHtml(o.id)}</code></td>
                <td>${formatTanggal(o.tanggal)}</td>
                <td>${escapeHtml(o.petugas)}</td>
                <td>${o.jumlahItem}</td>
                <td><span class="badge ${selisihBadge}">${o.selisih > 0 ? '+' : ''}${o.selisih} item</span></td>
                <td><span class="badge ${o.status === 'Selesai' ? 'badge-green' : 'badge-yellow'}">${escapeHtml(o.status)}</span></td>
                <td><div class="td-actions">
                    <button class="btn btn-info btn-sm" onclick="lihatOpname(${i})" aria-label="Lihat detail" title="Lihat Detail"><i data-lucide="eye"></i></button>
                    ${o.status === 'Draft' ? `<button class="btn btn-primary btn-sm" onclick="selesaikanOpname(${i})">Selesaikan</button>` : ''}
                </div></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(7, 'Belum ada sesi opname', 'Klik Mulai Opname untuk memulai');
    const info = document.getElementById('info-opname');
    if (info) info.textContent = `Menampilkan ${DATA_OPNAME.length} data`;
    lucide.createIcons();
}

function openTambahOpname() {
    document.getElementById('form-opname').reset();
    document.getElementById('fo-no').value      = nextKode('OPN', DATA_OPNAME);
    document.getElementById('fo-tanggal').value = hariIni();
    populateKasirSelects();
    populateKategoriSelect();
    const kat = document.getElementById('fo-kategori');
    if (kat) {
        kat.innerHTML = '<option value="">Semua Kategori</option>' +
            DATA_KATEGORI.map(k => `<option value="${escapeHtml(k.nama)}">${escapeHtml(k.nama)}</option>`).join('');
    }
    openModal('modal-stock-opname');
}

async function simpanOpname() {
    const kategori = document.getElementById('fo-kategori').value;
    const petugas  = document.getElementById('fo-petugas').value;
    if (!petugas) { showToast('error', 'Pilih petugas opname!'); return; }

    const cakupan = kategori ? DATA_BARANG.filter(b => b.kategori === kategori) : DATA_BARANG;
    if (!cakupan.length) {
        showToast('error', kategori ? `Tidak ada barang di kategori "${kategori}".` : 'Belum ada barang untuk diopname.');
        return;
    }

    const data = {
        id:         document.getElementById('fo-no').value,
        tanggal:    document.getElementById('fo-tanggal').value || hariIni(),
        petugas,
        jumlahItem: cakupan.length,
        selisih:    0,
        catatan:    document.getElementById('fo-ket').value.trim() || (kategori ? `Kategori: ${kategori}` : 'Semua kategori'),
        status:     'Draft',
    };

    const savedId = await dbUpsertOpname(data);
    if (savedId) data.dbId = savedId;
    else showToast('warning', 'Tersimpan lokal, gagal sync ke server.');

    DATA_OPNAME.unshift(data);
    closeModal('modal-stock-opname');
    renderOpname();
    showToast('success', `Sesi opname dimulai untuk ${cakupan.length} barang. Catat selisihnya lewat Penyesuaian Stok.`);
}

// Sesi opname 'Draft' terbaru milik petugas tertentu — dipakai untuk menautkan
// Penyesuaian Stok yang dibuat berikutnya ke sesi opname yang sedang berjalan.
function opnameAktifUntuk(petugas) {
    return DATA_OPNAME.find(o => o.status === 'Draft' && o.petugas === petugas) || null;
}

function lihatOpname(idx) {
    const o = DATA_OPNAME[idx];
    const terkait = o.dbId ? DATA_ADJ.filter(a => a.idOpname === o.dbId) : [];
    const rincian = terkait.length
        ? terkait.map(a => `• ${a.namaProduk}: ${a.stokSistem} → ${a.stokFisik} (${a.selisih > 0 ? '+' : ''}${a.selisih})`).join('\n')
        : 'Belum ada penyesuaian stok yang tercatat pada tanggal ini.';
    showConfirm(`Detail ${o.id}`,
        `Petugas: ${o.petugas}\nTanggal: ${formatTanggal(o.tanggal)}\nCakupan: ${o.jumlahItem} item\nCatatan: ${o.catatan}\n\n${rincian}`,
        () => {}, { type: 'primary', icon: 'clipboard-list', btnText: 'Tutup' });
}

function selesaikanOpname(idx) {
    const o = DATA_OPNAME[idx];
    showConfirm('Selesaikan Opname', `Tandai sesi "${o.id}" sebagai selesai? Selisih akan dikunci dari penyesuaian stok tanggal ${formatTanggal(o.tanggal)}.`, async () => {
        o.selisih = (o.dbId ? DATA_ADJ.filter(a => a.idOpname === o.dbId) : []).reduce((s, a) => s + Number(a.selisih || 0), 0);
        o.status  = 'Selesai';
        await dbUpsertOpname(o);
        renderOpname();
        showToast('success', `Opname ${o.id} selesai dengan selisih ${o.selisih} item.`);
    }, { type: 'primary', icon: 'check-circle', btnText: 'Ya, Selesaikan' });
}

// ── PENYESUAIAN STOK ─────────────────────────────────────────────────────────
function renderAdj() {
    const tbody = document.querySelector('#tbl-adj tbody');
    if (!tbody) return;
    tbody.innerHTML = DATA_ADJ.length
        ? DATA_ADJ.map(a => {
            const badge = a.selisih === 0 ? 'badge-gray' : (a.selisih < 0 ? 'badge-red' : 'badge-green');
            return `<tr>
                <td>${formatTanggal(a.tanggal)}</td>
                <td><strong>${escapeHtml(a.namaProduk)}</strong></td>
                <td>${a.stokSistem}</td>
                <td>${a.stokFisik}</td>
                <td><span class="badge ${badge}">${a.selisih > 0 ? '+' : ''}${a.selisih}</span></td>
                <td>${escapeHtml(a.keterangan) || '—'}</td>
                <td>${escapeHtml(a.petugas)}</td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(7, 'Belum ada penyesuaian stok', 'Klik Buat Penyesuaian untuk mencatat koreksi stok');
    const info = document.getElementById('info-adj');
    if (info) info.textContent = `Menampilkan ${DATA_ADJ.length} data`;
    lucide.createIcons();
}

function isiStokSistem() {
    const nama = document.getElementById('fa-barang').value;
    const b = DATA_BARANG.find(x => x.nama === nama);
    document.getElementById('fa-sistem').value = b ? b.stok : 0;
    hitungSelisihAdj();
}

function hitungSelisihAdj() {
    const sistem = parseInt(document.getElementById('fa-sistem').value, 10) || 0;
    const fisik  = parseInt(document.getElementById('fa-fisik').value, 10);
    const el = document.getElementById('fa-selisih');
    if (!el) return;
    if (isNaN(fisik)) { el.value = '0'; return; }
    const selisih = fisik - sistem;
    el.value = `${selisih > 0 ? '+' : ''}${selisih}`;
}

function openTambahAdjStok() {
    document.getElementById('form-adj-stok').reset();
    populateProdukSelect('fa-barang');
    document.getElementById('fa-sistem').value  = 0;
    document.getElementById('fa-selisih').value = 0;
    openModal('modal-adj-stok');
}

async function simpanAdjStok() {
    const nama  = document.getElementById('fa-barang').value;
    const fisik = parseInt(document.getElementById('fa-fisik').value, 10);
    const ket   = document.getElementById('fa-ket').value.trim();

    if (!nama)         { showToast('error', 'Pilih barang yang akan disesuaikan!'); return; }
    if (isNaN(fisik) || fisik < 0) { showToast('error', 'Stok fisik harus angka 0 atau lebih!'); return; }
    if (!ket)          { showToast('error', 'Keterangan penyesuaian wajib diisi!'); return; }

    const barang = DATA_BARANG.find(b => b.nama === nama);
    if (!barang) { showToast('error', 'Barang tidak ditemukan.'); return; }

    const stokSistem = Number(barang.stok || 0);
    const selisih = fisik - stokSistem;
    if (selisih === 0) {
        showToast('info', 'Stok fisik sama dengan stok sistem, tidak ada yang perlu disesuaikan.');
        return;
    }

    const petugas = namaPetugas();
    const opname = opnameAktifUntuk(petugas);

    const data = {
        id: 'ADJ-' + Date.now(),
        tanggal: hariIni(),
        namaProduk: nama,
        stokSistem,
        stokFisik: fisik,
        selisih,
        keterangan: ket,
        petugas,
        idOpname: opname ? opname.dbId : null,
    };

    const savedId = await dbInsertAdjustment(data);
    if (savedId) data.id = savedId;
    else showToast('warning', 'Tersimpan lokal, gagal sync ke server.');  // id lokal sudah dibuat di atas

    DATA_ADJ.unshift(data);

    // Stok sistem dipaksa mengikuti hasil hitung fisik.
    barang.stok = fisik;
    await dbUpdateStok(barang.id, fisik);

    closeModal('modal-adj-stok');
    renderAdj();
    renderBarang();
    renderLaporanStok();
    updateDashboard();
    showToast('success', `Stok "${nama}" disesuaikan ${selisih > 0 ? '+' : ''}${selisih} menjadi ${fisik}.`);
}

// ── LAPORAN PEMBELIAN ────────────────────────────────────────────────────────
function renderLaporanPembelian(data) {
    data = data || DATA_PEMBELIAN;
    const tbody = document.querySelector('#tbl-lap-pembelian tbody');
    if (!tbody) return;
    tbody.innerHTML = data.length
        ? data.map(p => `<tr>
            <td>${formatTanggal(p.tanggal)}</td>
            <td><code class="inv-code">${escapeHtml(p.noFaktur)}</code></td>
            <td>${escapeHtml(p.supplier)}</td>
            <td>${formatRp(p.total)}</td>
            <td><span class="badge ${badgePembelian(p.status)}">${escapeHtml(p.status)}</span></td>
        </tr>`).join('')
        : tableEmptyHTML(5, 'Tidak ada data pembelian', 'Coba ubah rentang tanggal atau supplier');

    const total  = data.reduce((s, p) => s + Number(p.total || 0), 0);
    const lunas  = data.reduce((s, p) => s + Number(p.terbayar || 0), 0);
    const hutang = data.reduce((s, p) => s + sisaTagihan(p), 0);
    const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setEl('lap-pb-total',  formatRp(total));
    setEl('lap-pb-lunas',  formatRp(lunas));
    setEl('lap-pb-hutang', formatRp(hutang));
    setEl('info-lap-pembelian', `Menampilkan ${data.length} dari ${DATA_PEMBELIAN.length} data`);
    lucide.createIcons();
}

function filterLaporanPembelian() {
    const dari     = document.getElementById('lap-pb-dari')?.value;
    const sampai   = document.getElementById('lap-pb-sampai')?.value;
    const supplier = document.getElementById('lap-pb-supplier')?.value;
    let data = DATA_PEMBELIAN;
    if (dari)     data = data.filter(p => p.tanggal >= dari);
    if (sampai)   data = data.filter(p => p.tanggal <= sampai);
    if (supplier) data = data.filter(p => p.supplier === supplier);
    renderLaporanPembelian(data);
}

function populateLapPembelianSupplier() {
    const sel = document.getElementById('lap-pb-supplier');
    if (!sel) return;
    const current = sel.value;
    sel.innerHTML = '<option value="">Semua Supplier</option>' +
        DATA_SUPPLIER.map(s => `<option value="${escapeHtml(s.nama)}">${escapeHtml(s.nama)}</option>`).join('');
    if (current) sel.value = current;
}

// ── LAPORAN HUTANG ───────────────────────────────────────────────────────────
function renderLaporanHutang() {
    const tbody = document.querySelector('#tbl-lap-hutang tbody');
    if (!tbody) return;
    const hutang = daftarHutang();
    tbody.innerHTML = hutang.length
        ? hutang.map(p => {
            const st = statusTagihan(p);
            return `<tr>
                <td>${escapeHtml(p.supplier)}</td>
                <td><code class="inv-code">${escapeHtml(p.noFaktur)}</code></td>
                <td>${formatTanggal(p.tanggal)}</td>
                <td>${p.jatuhTempo ? formatTanggal(p.jatuhTempo) : '—'}</td>
                <td>${formatRp(p.total)}</td>
                <td><strong>${formatRp(sisaTagihan(p))}</strong></td>
                <td><span class="badge ${st.badge}">${st.teks}</span></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(7, 'Tidak ada hutang aktif', 'Semua tagihan supplier sudah lunas');

    const totalHutang = hutang.reduce((s, p) => s + sisaTagihan(p), 0);
    const jatuhTempo  = hutang.filter(p => lewatJatuhTempo(p.jatuhTempo)).reduce((s, p) => s + sisaTagihan(p), 0);
    const dibayar     = DATA_PEMBELIAN.reduce((s, p) => s + Number(p.terbayar || 0), 0);
    const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setEl('lap-hutang-total',   formatRp(totalHutang));
    setEl('lap-hutang-tempo',   formatRp(jatuhTempo));
    setEl('lap-hutang-dibayar', formatRp(dibayar));
    setEl('info-lap-hutang', `Menampilkan ${hutang.length} data`);
    lucide.createIcons();
}

// ── LAPORAN KAS ──────────────────────────────────────────────────────────────
function renderLaporanKas(data) {
    const tbody = document.querySelector('#tbl-lap-kas tbody');
    if (!tbody) return;
    const sumber = data || DATA_KAS;
    const rows = kasDenganSaldo(sumber).reverse();

    tbody.innerHTML = rows.length
        ? rows.map(k => `<tr>
            <td>${formatTanggal(k.tanggal)}</td>
            <td>${escapeHtml(k.kasir) || '—'}</td>
            <td>${escapeHtml(k.keterangan)}</td>
            <td>${k.tipe === 'masuk' ? formatRp(k.nominal) : '—'}</td>
            <td>${k.tipe === 'keluar' ? formatRp(k.nominal) : '—'}</td>
            <td><strong>${formatRp(k.saldo)}</strong></td>
        </tr>`).join('')
        : tableEmptyHTML(6, 'Tidak ada mutasi kas', 'Coba ubah rentang tanggal atau kasir');

    const masuk  = sumber.filter(k => k.tipe === 'masuk').reduce((s, k) => s + Number(k.nominal || 0), 0);
    const keluar = sumber.filter(k => k.tipe === 'keluar').reduce((s, k) => s + Number(k.nominal || 0), 0);
    const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
    setEl('lap-kas-masuk',  formatRp(masuk));
    setEl('lap-kas-keluar', formatRp(keluar));
    setEl('lap-kas-saldo',  formatRp(masuk - keluar));
    setEl('info-lap-kas', `Menampilkan ${rows.length} dari ${DATA_KAS.length} mutasi`);
    lucide.createIcons();
}

function filterLaporanKas() {
    const dari   = document.getElementById('lap-kas-dari')?.value;
    const sampai = document.getElementById('lap-kas-sampai')?.value;
    const kasir  = document.getElementById('lap-kas-kasir')?.value;
    let data = DATA_KAS;
    if (dari)   data = data.filter(k => k.tanggal >= dari);
    if (sampai) data = data.filter(k => k.tanggal <= sampai);
    if (kasir)  data = data.filter(k => k.kasir === kasir);
    renderLaporanKas(data);
}

// ── SHIFT KASIR ──────────────────────────────────────────────────────────────
function _formatJam(isoStr) {
    if (!isoStr) return '—';
    return new Date(isoStr).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
}

function renderShiftBadge() {
    const badge = document.getElementById('shift-badge');
    if (!badge) return;
    if (DATA_SHIFT_AKTIF) {
        badge.textContent = `Shift: ${DATA_SHIFT_AKTIF.kasirNama} (${formatRp(DATA_SHIFT_AKTIF.modalAwal)})`;
        badge.className = 'shift-badge shift-buka';
        badge.title = `Shift dibuka ${_formatJam(DATA_SHIFT_AKTIF.waktuBuka)}`;
    } else {
        badge.textContent = 'Shift Belum Dibuka';
        badge.className = 'shift-badge shift-tutup';
        badge.title = 'Klik untuk membuka shift';
    }
}

function renderShiftKasir() {
    const tbody = document.querySelector('#tbl-shift tbody');
    if (!tbody) return;

    // Kartu shift aktif
    const aktifCard = document.getElementById('shift-aktif-card');
    const aktifContent = document.getElementById('shift-aktif-content');
    if (aktifCard && aktifContent) {
        if (DATA_SHIFT_AKTIF) {
            const s = DATA_SHIFT_AKTIF;
            const local = kasUntukShift(s.id);
            const kasMasukLainnya = local.masuk - local.totalTunai;
            const saldoSeharusnya = s.modalAwal + local.masuk - local.keluar;
            aktifContent.innerHTML = `
                <div style="display:flex;align-items:center;gap:10px;margin-bottom:14px">
                    <span class="badge badge-green" style="font-size:12px;padding:4px 12px">● SHIFT AKTIF</span>
                    <strong style="font-size:15px">${escapeHtml(s.kasirNama)}</strong>
                    <span style="color:var(--text-muted);font-size:13px">· Buka sejak ${_formatJam(s.waktuBuka)}</span>
                </div>
                <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px">
                    <div style="background:var(--bg);border-radius:10px;padding:12px">
                        <div style="font-size:11px;color:var(--text-muted);margin-bottom:4px">Modal Awal</div>
                        <div style="font-size:15px;font-weight:700">${formatRp(s.modalAwal)}</div>
                    </div>
                    <div style="background:var(--bg);border-radius:10px;padding:12px">
                        <div style="font-size:11px;color:var(--text-muted);margin-bottom:4px">Total Tunai</div>
                        <div style="font-size:15px;font-weight:700;color:var(--primary)">${formatRp(local.totalTunai)}</div>
                    </div>
                    <div style="background:var(--bg);border-radius:10px;padding:12px">
                        <div style="font-size:11px;color:var(--text-muted);margin-bottom:4px">Kas Masuk Lainnya</div>
                        <div style="font-size:15px;font-weight:700;color:var(--primary)">${formatRp(kasMasukLainnya)}</div>
                    </div>
                    <div style="background:var(--bg);border-radius:10px;padding:12px">
                        <div style="font-size:11px;color:var(--text-muted);margin-bottom:4px">Kas Keluar</div>
                        <div style="font-size:15px;font-weight:700;color:var(--danger)">${formatRp(local.keluar)}</div>
                    </div>
                    <div style="background:var(--primary-light,#f0fdf4);border-radius:10px;padding:12px;border:1px solid var(--primary-border,#bbf7d0)">
                        <div style="font-size:11px;color:var(--text-muted);margin-bottom:4px">Saldo Seharusnya</div>
                        <div style="font-size:17px;font-weight:800;color:var(--primary)">${formatRp(saldoSeharusnya)}</div>
                    </div>
                </div>`;
            aktifCard.style.display = '';
        } else {
            aktifCard.style.display = 'none';
        }
    }

    // Filter status
    const filterStatus = document.getElementById('filter-shift-status')?.value ?? '';
    const list = filterStatus ? DATA_SHIFT_LIST.filter(s => s.status === filterStatus) : DATA_SHIFT_LIST;

    tbody.innerHTML = list.length
        ? list.map(s => {
            const durasi = s.waktuTutup
                ? (() => {
                    const mnt = Math.round((new Date(s.waktuTutup) - new Date(s.waktuBuka)) / 60000);
                    return mnt >= 60 ? `${Math.floor(mnt/60)}j ${mnt%60}m` : `${mnt} mnt`;
                })()
                : '—';
            let selisihHtml = '—';
            if (s.selisih != null) {
                const cls = s.selisih === 0 ? 'badge-green' : s.selisih > 0 ? 'badge-blue' : 'badge-red';
                const label = s.selisih === 0 ? 'Pas' : (s.selisih > 0 ? `+${formatRp(s.selisih)}` : formatRp(s.selisih));
                selisihHtml = `<span class="badge ${cls}">${label}</span>`;
            }
            return `<tr>
                <td>${formatTanggal(s.tanggal)}</td>
                <td><strong>${escapeHtml(s.kasirNama)}</strong></td>
                <td>${_formatJam(s.waktuBuka)}</td>
                <td>${_formatJam(s.waktuTutup)}</td>
                <td style="color:var(--text-muted)">${durasi}</td>
                <td>${formatRp(s.modalAwal)}</td>
                <td style="color:var(--primary)">${formatRp(s.totalTunai)}</td>
                <td style="color:var(--primary)">${formatRp(s.kasMasuk)}</td>
                <td style="color:var(--danger)">${formatRp(s.kasKeluar)}</td>
                <td>${s.saldoAkhir != null ? formatRp(s.saldoAkhir) : '—'}</td>
                <td>${selisihHtml}</td>
                <td><span class="badge ${s.status === 'buka' ? 'badge-green' : 'badge-gray'}">${s.status === 'buka' ? 'Aktif' : 'Selesai'}</span></td>
            </tr>`;
        }).join('')
        : tableEmptyHTML(12, 'Belum ada riwayat shift', 'Klik Buka Shift untuk memulai');
    const info = document.getElementById('info-shift');
    if (info) info.textContent = `Menampilkan ${list.length} sesi`;
    lucide.createIcons();
}

function openBukaShift() {
    if (DATA_SHIFT_AKTIF) {
        showToast('warning', `Shift "${DATA_SHIFT_AKTIF.kasirNama}" masih aktif. Tutup terlebih dahulu.`);
        return;
    }
    document.getElementById('form-buka-shift').reset();
    document.getElementById('fsh-kasir').value = namaPetugas();
    document.getElementById('fsh-tanggal').value = hariIni();
    openModal('modal-buka-shift');
}

async function simpanBukaShift() {
    const kasirNama = document.getElementById('fsh-kasir').value.trim();
    const modalAwal = parseInt(document.getElementById('fsh-kas-awal').value, 10) || 0;
    if (!kasirNama) { showToast('error', 'Pilih kasir terlebih dahulu!'); return; }

    const entry = {
        kasirNama, modalAwal,
        tanggal: hariIni(),
        waktuBuka: new Date().toISOString(),
        waktuTutup: null,
        totalTunai: 0, kasMasuk: 0, kasKeluar: 0,
        saldoAkhir: null, selisih: null,
        status: 'buka',
    };

    const savedId = await dbBukaShift(entry);
    if (savedId) {
        entry.id = savedId;
    } else {
        showToast('warning', 'Shift tersimpan lokal, gagal sync server.');
        entry.id = 'SHF-' + Date.now();
    }
    DATA_SHIFT_AKTIF = entry;
    DATA_SHIFT_LIST.unshift(entry);

    closeModal('modal-buka-shift');
    renderShiftBadge();
    renderShiftKasir();
    showToast('success', `Shift dibuka — modal awal ${formatRp(modalAwal)}`);
}

// Kas masuk/keluar sesi shift ini, dihitung dari kas_log yang sudah difilter
// id_shift (bukan dari s.totalTunai/kasMasuk/kasKeluar lokal yang tidak
// pernah di-increment) — lihat supabase/migration_kas_shift_realtime.sql.
// `totalTunai` = subset penjualan tunai (keterangan diawali 'Penjualan '),
// `masuk` = SEMUA kas masuk shift ini (penjualan tunai + DP piutang +
// pelunasan cicilan + manual) — dipakai untuk saldoSeharusnya supaya tidak
// dobel-hitung. `masuk - totalTunai` = kas masuk selain penjualan (buat
// ditampilkan terpisah di riwayat shift).
function kasUntukShift(shiftId) {
    const rows = DATA_KAS.filter(k => k.idShift === String(shiftId));
    const masuk  = rows.filter(k => k.tipe === 'masuk').reduce((s, k) => s + Number(k.nominal || 0), 0);
    const keluar = rows.filter(k => k.tipe === 'keluar').reduce((s, k) => s + Number(k.nominal || 0), 0);
    const totalTunai = rows
        .filter(k => k.tipe === 'masuk' && String(k.keterangan || '').startsWith('Penjualan '))
        .reduce((s, k) => s + Number(k.nominal || 0), 0);
    return { masuk, keluar, totalTunai };
}

// Rincian kas kasir shift berjalan, dipecah per komponen sesuai rumus:
//   kas kasir = (omzet + kas terakhir/modal awal + kas masuk)
//             − (piutang + nontunai + kas keluar + pembelian tunai)
// `omzet/piutang/nontunai` dihitung dari transaksi yang jatuh di rentang jam
// shift ini (tanggal+jam, bukan cuma tanggal — supaya benar walau toko buka
// >1 shift/hari). `kas masuk/keluar/pembelian tunai` dihitung dari kas_log
// yang sudah ditandai id_shift oleh trigger DB — lihat kasUntukShift() &
// supabase/migration_kas_shift_realtime.sql.
//
// `total` di sini harus SELALU sama dengan saldoSeharusnya (modalAwal + masuk
// − keluar dari kasUntukShift/fn_shift_saldo) — omzet-piutang-nontunai secara
// matematis persis sama dengan "penjualan tunai + DP piutang" yang sudah
// tercatat otomatis di kas_log. Kalau angkanya beda, curigai ada transaksi
// yang jam-nya di luar rentang shift (mis. input backdated).
function rincianKasKasir(shift) {
    const mulai   = new Date(shift.waktuBuka);
    const selesai = shift.waktuTutup ? new Date(shift.waktuTutup) : new Date();

    const trxShift = DATA_PENJUALAN.filter(t => {
        if (!t.tanggal) return false;
        const waktu = new Date(`${t.tanggal}T${t.jam || '00:00'}:00`);
        return waktu >= mulai && waktu <= selesai;
    });

    const omzet    = trxShift.reduce((s, t) => s + Number(t.total || 0), 0);
    const piutang  = trxShift
        .filter(t => t.status === 'Piutang')
        .reduce((s, t) => s + (Number(t.total || 0) - Number(t.terbayar || 0)), 0);
    const nontunai = trxShift
        .filter(t => t.metode !== 'Tunai')
        .reduce((s, t) => s + Number(t.total || 0), 0);

    const rows = DATA_KAS.filter(k => k.idShift === String(shift.id));
    const sumTipe = (tipe, cocok) => rows
        .filter(k => k.tipe === tipe && cocok(String(k.keterangan || '')))
        .reduce((s, k) => s + Number(k.nominal || 0), 0);

    // Kas masuk lain-lain = pelunasan piutang lama + setoran manual (penjualan
    // tunai & DP piutang sudah terwakili lewat omzet di atas, jangan dobel).
    const kasMasuk       = sumTipe('masuk',  ket => !ket.startsWith('Penjualan ') && !ket.startsWith('DP Piutang '));
    // Kas keluar lain-lain = bayar hutang tunai + pengeluaran manual (di luar pembelian).
    const kasKeluarLain  = sumTipe('keluar', ket => !ket.startsWith('Pembelian '));
    const pembelianTunai = sumTipe('keluar', ket => ket.startsWith('Pembelian '));

    const kasTerakhir = Number(shift.modalAwal || 0);
    const total = (omzet + kasTerakhir + kasMasuk) - (piutang + nontunai + kasKeluarLain + pembelianTunai);

    return { omzet, kasTerakhir, kasMasuk, piutang, nontunai, kasKeluarLain, pembelianTunai, total };
}

async function openTutupShift() {
    if (!DATA_SHIFT_AKTIF) { showToast('warning', 'Tidak ada shift aktif.'); return; }
    const s = DATA_SHIFT_AKTIF;
    const local = kasUntukShift(s.id);
    const saldoServer = await dbShiftSaldo(s.id);
    const saldoSeharusnya = saldoServer != null ? saldoServer : (s.modalAwal + local.masuk - local.keluar);
    document.getElementById('tutup-shift-ringkasan').innerHTML = `
        <table style="width:100%;border-collapse:collapse;font-size:14px">
            <tr><td style="padding:6px 0;color:var(--text-muted)">Kasir</td><td style="padding:6px 0;text-align:right;font-weight:600">${escapeHtml(s.kasirNama)}</td></tr>
            <tr><td style="padding:6px 0;color:var(--text-muted)">Jam Buka</td><td style="padding:6px 0;text-align:right">${_formatJam(s.waktuBuka)}</td></tr>
            <tr><td style="padding:6px 0;color:var(--text-muted);border-top:1px solid var(--border)">Modal Awal</td><td style="padding:6px 0;text-align:right;border-top:1px solid var(--border)">${formatRp(s.modalAwal)}</td></tr>
            <tr><td style="padding:6px 0;color:var(--text-muted)">Kas Masuk (termasuk penjualan tunai)</td><td style="padding:6px 0;text-align:right;color:var(--primary)">${formatRp(local.masuk)}</td></tr>
            <tr><td style="padding:6px 0;color:var(--text-muted)">Kas Keluar</td><td style="padding:6px 0;text-align:right;color:var(--danger)">− ${formatRp(local.keluar)}</td></tr>
            <tr style="font-weight:700"><td style="padding:8px 0;border-top:2px solid var(--border)">Saldo Seharusnya</td><td style="padding:8px 0;text-align:right;border-top:2px solid var(--border);color:var(--primary);font-size:16px">${formatRp(saldoSeharusnya)}</td></tr>
        </table>`;
    document.getElementById('fts-saldo-fisik').value = '';
    document.getElementById('tutup-shift-selisih').style.display = 'none';
    openModal('modal-tutup-shift');
}

async function hitungSelisihTutup() {
    if (!DATA_SHIFT_AKTIF) return;
    const s = DATA_SHIFT_AKTIF;
    const saldoFisik = parseInt(document.getElementById('fts-saldo-fisik').value, 10) || 0;
    const local = kasUntukShift(s.id);
    const saldoServer = await dbShiftSaldo(s.id);
    const saldoSeharusnya = saldoServer != null ? saldoServer : (s.modalAwal + local.masuk - local.keluar);
    const selisih = saldoFisik - saldoSeharusnya;
    const el = document.getElementById('tutup-shift-selisih');
    if (!el) return;
    el.style.display = '';
    if (selisih === 0) {
        el.innerHTML = `<div class="badge badge-green" style="font-size:13px;padding:8px 16px;display:block;text-align:center">✓ Pas — Saldo sesuai</div>`;
    } else if (selisih > 0) {
        el.innerHTML = `<div class="badge badge-blue" style="font-size:13px;padding:8px 16px;display:block;text-align:center">↑ Lebih ${formatRp(selisih)} dari seharusnya</div>`;
    } else {
        el.innerHTML = `<div class="badge badge-red" style="font-size:13px;padding:8px 16px;display:block;text-align:center">↓ Kurang ${formatRp(Math.abs(selisih))} dari seharusnya</div>`;
    }
}

async function simpanTutupShift() {
    if (!DATA_SHIFT_AKTIF) return;
    const s = DATA_SHIFT_AKTIF;
    const saldoFisik = parseInt(document.getElementById('fts-saldo-fisik').value, 10) || 0;
    const local = kasUntukShift(s.id);
    const saldoServer = await dbShiftSaldo(s.id);
    const saldoSeharusnya = saldoServer != null ? saldoServer : (s.modalAwal + local.masuk - local.keluar);
    const selisih = saldoFisik - saldoSeharusnya;

    // total_tunai = penjualan tunai saja; kas_masuk = kas masuk LAINNYA (DP
    // piutang, pelunasan cicilan, manual) — supaya tidak dobel dengan
    // total_tunai saat keduanya ditampilkan berdampingan di riwayat shift.
    const kasMasukLainnya = local.masuk - local.totalTunai;
    const ok = await dbTutupShift(s.id, local.totalTunai, kasMasukLainnya, local.keluar, saldoFisik, selisih);

    const inList = DATA_SHIFT_LIST.find(x => x.id === s.id);
    if (inList) {
        inList.status = 'tutup';
        inList.waktuTutup = new Date().toISOString();
        inList.totalTunai = local.totalTunai;
        inList.kasMasuk = kasMasukLainnya;
        inList.kasKeluar = local.keluar;
        inList.saldoAkhir = saldoFisik;
        inList.selisih = selisih;
    }
    DATA_SHIFT_AKTIF = null;

    closeModal('modal-tutup-shift');
    renderShiftBadge();
    renderShiftKasir();
    const selisihMsg = selisih === 0 ? '' : ` (selisih ${selisih > 0 ? '+' : ''}${formatRp(selisih)})`;
    showToast('success', `Shift ditutup. Saldo akhir: ${formatRp(saldoFisik)}${selisihMsg}`);
    if (!ok) showToast('warning', 'Gagal sync ke server.');
}

// ── LOG STOK ─────────────────────────────────────────────────────────────────
function renderStokLog() {
    const tbody = document.querySelector('#tbl-stok-log tbody');
    if (!tbody) return;
    const tipeBadge = { penjualan: 'badge-red', pembelian: 'badge-green', retur: 'badge-yellow', opname: 'badge-blue', koreksi: 'badge-gray' };
    tbody.innerHTML = DATA_STOK_LOG.length
        ? DATA_STOK_LOG.map(l => `<tr>
            <td>${formatTanggal(l.tanggal)}</td>
            <td><strong>${escapeHtml(l.namaProduk)}</strong></td>
            <td>${l.stokSebelum}</td>
            <td>${l.stokSesudah}</td>
            <td><span class="badge ${l.selisih > 0 ? 'badge-green' : l.selisih < 0 ? 'badge-red' : 'badge-gray'}">${l.selisih > 0 ? '+' : ''}${l.selisih}</span></td>
            <td><span class="badge ${tipeBadge[l.tipe] || 'badge-gray'}">${escapeHtml(l.tipe)}</span></td>
            <td>${escapeHtml(l.referensi || '—')}</td>
        </tr>`).join('')
        : tableEmptyHTML(7, 'Belum ada log pergerakan stok', 'Log akan muncul setelah ada penyesuaian stok');
    const info = document.getElementById('info-stok-log');
    if (info) info.textContent = `Menampilkan ${DATA_STOK_LOG.length} entri`;
    lucide.createIcons();
}

// ── EXPORT / CETAK / BACKUP ──────────────────────────────────────────────────
// Sebelumnya semua tombol ini cuma memunculkan toast palsu tanpa menghasilkan file.
function exportCSV(tableId, namaFile) {
    const table = document.getElementById(tableId);
    if (!table) { showToast('error', 'Tabel tidak ditemukan.'); return; }

    const firstDataRow = table.querySelector('tbody tr:not(.skeleton-row)');
    const actionCols = new Set();
    if (firstDataRow) {
        [...firstDataRow.querySelectorAll('td')].forEach((td, i) => {
            if (td.querySelector('.td-actions')) actionCols.add(i);
        });
    }

    const baris = [...table.querySelectorAll('tr')]
        .filter(tr => !tr.querySelector('.table-empty-state') && !tr.classList.contains('skeleton-row'))
        .filter(tr => tr.offsetParent !== null || tr.parentElement.tagName === 'THEAD')
        .map(tr => [...tr.querySelectorAll('th,td')]
            .filter((sel, i) => !sel.querySelector('.td-actions') && !actionCols.has(i))
            .map(sel => `"${sel.textContent.trim().replace(/\s+/g, ' ').replace(/"/g, '""')}"`)
            .join(','));

    if (baris.length <= 1) { showToast('warning', 'Tidak ada data untuk diexport.'); return; }

    const blob = new Blob(['﻿' + baris.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href = url;
    a.download = `${namaFile}-${hariIni()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
    showToast('success', `${baris.length - 1} baris diexport ke ${a.download}`);
}

function cetakLaporan(pageId) {
    const page = document.getElementById(pageId);
    if (!page) { showToast('error', 'Halaman laporan tidak ditemukan.'); return; }
    const w = window.open('', '_blank');
    if (!w) { showToast('error', 'Popup diblokir browser. Izinkan popup untuk mencetak.'); return; }
    const judul = page.querySelector('h2')?.textContent || 'Laporan';
    w.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>${judul} — FABIZO</title>
        <style>
            body{font-family:system-ui,-apple-system,sans-serif;padding:24px;color:#0f172a}
            h1{font-size:18px;margin:0 0 4px}
            .meta{font-size:12px;color:#64748b;margin-bottom:16px}
            table{width:100%;border-collapse:collapse;font-size:12px}
            th,td{border:1px solid #cbd5e1;padding:6px 8px;text-align:left}
            th{background:#f1f5f9}
            .td-actions,.page-actions,.laporan-filter{display:none}
        </style></head><body>
        <h1>${judul}</h1>
        <div class="meta">FABIZO · Dicetak ${new Date().toLocaleString('id-ID')} oleh ${namaPetugas()}</div>
        ${[...page.querySelectorAll('table')].map(t => t.outerHTML).join('<br>')}
        </body></html>`);
    w.document.close();
    w.focus();
    setTimeout(() => w.print(), 300);
}

function simpanPengaturan(bagian) {
    const ambil = (id) => document.getElementById(id)?.value ?? '';
    const semua = JSON.parse(localStorage.getItem('ugt_settings') || '{}');

    if (bagian === 'toko') {
        const nama = ambil('set-toko-nama').trim();
        if (!nama) { showToast('error', 'Nama toko wajib diisi!'); return; }
        semua.toko = {
            nama, telp: ambil('set-toko-telp'), email: ambil('set-toko-email'),
            alamat: ambil('set-toko-alamat'), kota: ambil('set-toko-kota'), kodePos: ambil('set-toko-pos'),
        };
    } else if (bagian === 'pajak') {
        const ppn = parseFloat(ambil('set-pajak-ppn'));
        const diskon = parseFloat(ambil('set-pajak-diskon'));
        if (isNaN(ppn) || ppn < 0 || ppn > 100)       { showToast('error', 'PPN harus antara 0–100%!'); return; }
        if (isNaN(diskon) || diskon < 0 || diskon > 100) { showToast('error', 'Diskon maks harus antara 0–100%!'); return; }
        semua.pajak = {
            ppn, diskonMaks: diskon,
            poinPerSeribu: parseFloat(ambil('set-pajak-poin')) || 0,
            minBelanjaPoin: parseInt(ambil('set-pajak-min'), 10) || 0,
        };
    } else if (bagian === 'struk') {
        semua.struk = {
            header: ambil('set-struk-header'), footer: ambil('set-struk-footer'),
            kertas: ambil('set-struk-kertas'), cetakOtomatis: ambil('set-struk-auto'),
        };
    }

    localStorage.setItem('ugt_settings', JSON.stringify(semua));
    showToast('success', 'Pengaturan berhasil disimpan!');
}

function muatPengaturan() {
    let semua;
    try { semua = JSON.parse(localStorage.getItem('ugt_settings') || '{}'); }
    catch { return; }
    const isi = (id, nilai) => { const el = document.getElementById(id); if (el && nilai !== undefined && nilai !== '') el.value = nilai; };

    if (semua.toko) {
        isi('set-toko-nama', semua.toko.nama);   isi('set-toko-telp', semua.toko.telp);
        isi('set-toko-email', semua.toko.email); isi('set-toko-alamat', semua.toko.alamat);
        isi('set-toko-kota', semua.toko.kota);   isi('set-toko-pos', semua.toko.kodePos);
    }
    if (semua.pajak) {
        isi('set-pajak-ppn', semua.pajak.ppn);   isi('set-pajak-diskon', semua.pajak.diskonMaks);
        isi('set-pajak-poin', semua.pajak.poinPerSeribu); isi('set-pajak-min', semua.pajak.minBelanjaPoin);
    }
    if (semua.struk) {
        isi('set-struk-header', semua.struk.header); isi('set-struk-footer', semua.struk.footer);
        isi('set-struk-kertas', semua.struk.kertas); isi('set-struk-auto', semua.struk.cetakOtomatis);
    }
}

function backupData() {
    const isi = {
        versi: '1.1',
        dibuat: new Date().toISOString(),
        oleh: namaPetugas(),
        data: {
            kategori: DATA_KATEGORI, barang: DATA_BARANG, supplier: DATA_SUPPLIER,
            member: DATA_MEMBER, penjualan: DATA_PENJUALAN, users: DATA_USERS,
            cabang: DATA_CABANG, reseller: DATA_RESELLER, pembelian: DATA_PEMBELIAN,
            returBeli: DATA_RETUR_BELI, returJual: DATA_RETUR_JUAL, kas: DATA_KAS,
            opname: DATA_OPNAME, adjustment: DATA_ADJ, pembayaran: DATA_PEMBAYARAN,
        },
        pengaturan: JSON.parse(localStorage.getItem('ugt_settings') || '{}'),
    };
    const blob = new Blob([JSON.stringify(isi, null, 2)], { type: 'application/json' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href = url;
    a.download = `backup-ugtmart-${hariIni()}.json`;
    a.click();
    URL.revokeObjectURL(url);
    showToast('success', `Backup tersimpan sebagai ${a.download}`);
}

function restoreData(input) {
    const file = input.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (e) => {
        let isi;
        try { isi = JSON.parse(e.target.result); }
        catch { showToast('error', 'File backup tidak valid (bukan JSON).'); input.value = ''; return; }

        if (!isi.data || typeof isi.data !== 'object') {
            showToast('error', 'Struktur file backup tidak dikenali.');
            input.value = '';
            return;
        }

        showConfirm('Restore Data',
            `Backup dari ${isi.dibuat ? new Date(isi.dibuat).toLocaleString('id-ID') : 'waktu tidak diketahui'} oleh ${isi.oleh || '—'}. ` +
            `Data yang tampil sekarang akan ditimpa (database di server tidak diubah). Lanjutkan?`,
            () => {
                const ganti = (arr, baru) => { if (Array.isArray(baru)) { arr.length = 0; baru.forEach(x => arr.push(x)); } };
                ganti(DATA_KATEGORI, isi.data.kategori);   ganti(DATA_BARANG, isi.data.barang);
                ganti(DATA_SUPPLIER, isi.data.supplier);   ganti(DATA_MEMBER, isi.data.member);
                ganti(DATA_PENJUALAN, isi.data.penjualan); ganti(DATA_USERS, isi.data.users);
                ganti(DATA_CABANG, isi.data.cabang);       ganti(DATA_RESELLER, isi.data.reseller);
                ganti(DATA_PEMBELIAN, isi.data.pembelian); ganti(DATA_RETUR_BELI, isi.data.returBeli);
                ganti(DATA_RETUR_JUAL, isi.data.returJual);ganti(DATA_KAS, isi.data.kas);
                ganti(DATA_OPNAME, isi.data.opname);       ganti(DATA_ADJ, isi.data.adjustment);
                ganti(DATA_PEMBAYARAN, isi.data.pembayaran);
                if (isi.pengaturan) localStorage.setItem('ugt_settings', JSON.stringify(isi.pengaturan));
                initPageData();
                muatPengaturan();
                showToast('success', 'Data berhasil direstore ke tampilan.');
            }, { type: 'warning', icon: 'upload', btnText: 'Ya, Restore' });
        input.value = '';
    };
    reader.readAsText(file);
}
