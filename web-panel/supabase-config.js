// Replace these with your actual Supabase project values
const SUPABASE_URL = 'https://oxktbostinewjosnnlvb.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im94a3Rib3N0aW5ld2pvc25ubHZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzMTM0NTgsImV4cCI6MjEwMDg4OTQ1OH0.hgHckyCEFzYw40syW0Dg_AlTfmM8NuZ7HbN1987xv4c';

const _sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

// ── MULTI-TENANCY — id_toko scope ────────────────────────────────────────────
// Diset setelah login; semua query data difilter berdasarkan nilai ini.
let _currentIdToko = null;

function setCurrentToko(idToko) {
    _currentIdToko = idToko ? Number(idToko) : null;
}

// ── REALTIME SYNC ─────────────────────────────────────────────────────────────
let _realtimeChannel = null;
let _realtimeTimer   = null;

function setupRealtime() {
    if (!_currentIdToko || _realtimeChannel) return;

    function _scheduleReload() {
        clearTimeout(_realtimeTimer);
        _realtimeTimer = setTimeout(async () => {
            try { await dbLoadAll(); } catch {}
            try { await dbLoadAllExtra(); } catch {}
            if (typeof initPageData === 'function') initPageData();
        }, 800);
    }

    _realtimeChannel = _sb.channel('pos-toko-' + _currentIdToko)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'produk',    filter: `id_toko=eq.${_currentIdToko}` }, _scheduleReload)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'member',    filter: `id_toko=eq.${_currentIdToko}` }, _scheduleReload)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'transaksi', filter: `id_toko=eq.${_currentIdToko}` }, _scheduleReload)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'supplier',  filter: `id_toko=eq.${_currentIdToko}` }, _scheduleReload)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'kas_log',   filter: `id_toko=eq.${_currentIdToko}` }, _scheduleReload)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'shift',     filter: `id_toko=eq.${_currentIdToko}` }, _scheduleReload)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'pembelian', filter: `id_toko=eq.${_currentIdToko}` }, _scheduleReload)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'pembayaran',filter: `id_toko=eq.${_currentIdToko}` }, _scheduleReload)
        .subscribe();
}

function teardownRealtime() {
    clearTimeout(_realtimeTimer);
    if (_realtimeChannel) {
        _sb.removeChannel(_realtimeChannel);
        _realtimeChannel = null;
    }
}

// ── AUTH ──────────────────────────────────────────────────────────────────────
async function dbValidateLogin(username, password) {
    try {
        // Step 1: Validasi username/password via RPC
        const { data, error } = await _sb.rpc('validate_login', {
            p_username: username,
            p_password: password,
        });
        if (error || !data || data.length === 0) return null;
        const user = data[0]; // { nama, role, id_toko, nama_toko, plan, expired_at, avatar_color }

        // Step 2: Login ke Supabase Auth supaya JWT punya id_toko (untuk RLS)
        const authEmail = `${username.toLowerCase().trim()}@ugtmart.internal`;
        const { error: signInErr } = await _sb.auth.signInWithPassword({
            email: authEmail,
            password: password,
        });

        if (signInErr) {
            // User belum ada di Supabase Auth — buat akun baru lalu login
            await _sb.auth.signUp({
                email: authEmail,
                password: password,
                options: {
                    data: {
                        id_toko: user.id_toko,
                        role:    user.role,
                        nama:    user.nama,
                    },
                },
            });
            await _sb.auth.signInWithPassword({ email: authEmail, password: password });
        }

        // Selalu update metadata supaya JWT punya id_toko terbaru
        // (mencakup kasus user lama yang dibuat sebelum metadata diset)
        await _sb.auth.updateUser({
            data: {
                id_toko: user.id_toko,
                role:    user.role,
                nama:    user.nama,
            },
        });

        return user;
    } catch { return null; }
}

async function dbSignOut() {
    try { await _sb.auth.signOut(); } catch (_) {}
}

// ── PRODUCTS (produk) ─────────────────────────────────────────────────────────
async function dbLoadProducts() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('produk')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('id');
    if (error) throw error;
    return data;
}

async function dbUploadFotoProduk(file, produkId) {
    const ext = file.name.split('.').pop().toLowerCase();
    const path = `${_currentIdToko}/${produkId || Date.now()}_${Date.now()}.${ext}`;
    const { error } = await _sb.storage.from('produk-foto').upload(path, file, { upsert: true });
    if (error) throw error;
    const { data } = _sb.storage.from('produk-foto').getPublicUrl(path);
    return data.publicUrl;
}

async function dbUpsertProduct(p) {
    const katEntry = DATA_KATEGORI.find(k => k.nama === p.kategori);
    const isNew = !p.id || isNaN(Number(p.id));
    const basePayload = {
        nama: p.nama,
        kategori: p.kategori,
        satuan: p.satuan,
        harga_beli: p.hargaBeli,
        harga_jual: p.hargaJual,
        stok: p.stok,
        stok_minimum: p.stokMin,
        barcode: p.barcode,
        status: p.status,
        id_kategori: katEntry && !isNaN(Number(katEntry.id)) ? Number(katEntry.id) : null,
        foto_url: p.fotoUrl ?? null,
    };

    if (isNew) {
        // INSERT: sertakan kode & id_toko
        if (!_currentIdToko) throw new Error('Sesi tidak valid. Silakan login ulang.');
        const insertPayload = {
            ...basePayload,
            kode: p.kode || ('BRG-' + Date.now()),
            id_toko: _currentIdToko,
        };
        const { data, error } = await _sb.from('produk').insert(insertPayload).select('id').single();
        if (error) { console.error('dbUpsertProduct insert:', error); return null; }
        return data?.id?.toString() ?? null;
    } else {
        // UPDATE: gunakan .update() bukan .upsert() agar trigger auto_kode tidak ikut jalan
        const { data, error } = await _sb.from('produk')
            .update(basePayload)
            .eq('id', Number(p.id))
            .select('id')
            .single();
        if (error) { console.error('dbUpsertProduct update:', error); return null; }
        return data?.id?.toString() ?? null;
    }
}

async function dbDeleteProduct(id) {
    const { error } = await _sb.from('produk').delete().eq('id', Number(id));
    if (error) console.error('dbDeleteProduct:', error);
}

// ── MEMBERS ───────────────────────────────────────────────────────────────────
async function dbLoadMembers() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('member')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('id');
    if (error) throw error;
    return data;
}

async function dbUpsertMember(m) {
    const isNew = !(m.id && !isNaN(Number(m.id)));
    const base = {
        nama: m.nama,
        no_hp: m.hp,
        email: m.email,
        alamat: m.alamat,
        poin: m.poin ?? 0,
        total_spend: m.spend ?? 0,
        aktif: m.status !== 'Non-aktif',
    };
    if (isNew) {
        if (!_currentIdToko) throw new Error('Sesi tidak valid. Silakan login ulang.');
        const { data, error } = await _sb.from('member')
            .insert({ ...base, kode: 'MBR-' + Date.now(), id_toko: _currentIdToko })
            .select('id').single();
        if (error) { console.error('dbUpsertMember insert:', error); return null; }
        return data?.id?.toString() ?? null;
    } else {
        const { data, error } = await _sb.from('member')
            .update(base).eq('id', Number(m.id)).select('id').single();
        if (error) { console.error('dbUpsertMember update:', error); return null; }
        return data?.id?.toString() ?? null;
    }
}

async function dbDeleteMember(id) {
    if (!(id && !isNaN(Number(id)))) return true;
    const { error } = await _sb.from('member').delete().eq('id', Number(id));
    if (error) { console.error('dbDeleteMember:', error); return false; }
    return true;
}

// ── TRANSACTIONS (transaksi) ──────────────────────────────────────────────────
async function dbLoadTransactions() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('transaksi')
        .select('*, transaksi_item(*)')
        .eq('id_toko', _currentIdToko)
        .order('created_at', { ascending: false })
        .limit(500);
    if (error) throw error;
    return data;
}

// `id` di sini harus id numerik (transaksi.id), bukan no_faktur.
// Bila yang tersedia hanya no_faktur, query jatuh ke kolom no_faktur.
async function dbLunasiPiutang(id, terbayar) {
    const patch = { status: 'Lunas' };
    if (terbayar !== undefined) patch.terbayar = terbayar;
    const query = _sb.from('transaksi').update(patch);
    const { error } = isNaN(Number(id)) ?
        await query.eq('no_faktur', id) :
        await query.eq('id', Number(id));
    if (error) { console.error('dbLunasiPiutang:', error); return false; }
    return true;
}

async function dbInsertTransaksi(data) {
    if (!_sb) return null;
    // 'Kartu Debit/Kredit' belum ada di CHECK constraint DB — petakan ke 'EDC BCA'
    const METODE_MAP = { 'Kartu Debit/Kredit': 'EDC BCA' };
    const metodeDB = METODE_MAP[data.metode] ?? data.metode;
    const metodeAllowed = ['Tunai', 'QRIS', 'EDC BCA', 'Voucher'];
    const payload = {
        no_faktur: data.id,
        tanggal: data.tanggal,
        kasir: data.kasir || 'Admin',
        pelanggan: data.pelanggan || 'Umum',
        metode_bayar: metodeAllowed.includes(metodeDB) ? metodeDB : 'Tunai',
        total: Number(data.total) || 0,
        terbayar: Number(data.terbayar) || 0,
        status: data.status || 'Lunas',
        jumlah_item: 0,
    };
    if (_currentIdToko) payload.id_toko = _currentIdToko;
    if (data.idReseller && !isNaN(Number(data.idReseller))) payload.id_reseller = Number(data.idReseller);
    const { data: row, error } = await _sb.from('transaksi').insert(payload).select('id').single();
    if (error) { console.error('dbInsertTransaksi:', error); return null; }
    return row?.id?.toString() ?? null;
}

// ── CATEGORIES (kategori) ─────────────────────────────────────────────────────
async function dbLoadKategori() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb.from('kategori')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('nama');
    if (error) throw error;
    return data;
}

async function dbUpsertKategori(k) {
    if (!_currentIdToko) throw new Error('Sesi tidak valid. Silakan login ulang.');
    const isNew = !k.id || isNaN(Number(k.id));
    const base = { nama: k.nama, deskripsi: k.deskripsi || '', status: k.status };
    if (isNew) {
        const { data, error } = await _sb.from('kategori')
            .insert({ ...base, kode: 'KT-' + Date.now(), id_toko: _currentIdToko })
            .select('id').single();
        if (error) { console.error('dbUpsertKategori insert:', error); return null; }
        return data?.id?.toString() ?? null;
    } else {
        const { data, error } = await _sb.from('kategori')
            .update(base).eq('id', Number(k.id)).select('id').single();
        if (error) { console.error('dbUpsertKategori update:', error); return null; }
        return data?.id?.toString() ?? null;
    }
}

async function dbDeleteKategori(id) {
    const { error } = await _sb.from('kategori').delete().eq('id', Number(id));
    if (error) { console.error('dbDeleteKategori:', error); return false; }
    return true;
}

// ── PROFILES / USERS ──────────────────────────────────────────────────────────
// All profile operations go through SECURITY DEFINER RPCs so the profiles
// table (which contains passwords) is never directly accessible via anon key.

async function dbLoadProfiles() {
    const { data, error } = await _sb.rpc('list_profiles', { p_id_toko: _currentIdToko });
    if (error) { console.warn('dbLoadProfiles:', error); return []; }
    return data ?? [];
}

async function dbUpsertProfile(u, password) {
    const roleColors = { 'Owner': '#16A34A', 'Admin': '#8B5CF6', 'Kasir': '#3B82F6' };
    const { data, error } = await _sb.rpc('save_profile', {
        p_id: u.id && !isNaN(Number(u.id)) ? Number(u.id) : null,
        p_username: u.username,
        p_nama: u.nama,
        p_role: u.role,
        p_password: password || null,
        p_avatar_color: roleColors[u.role] || '#16A34A',
        p_aktif: u.status !== 'Non-aktif',
        p_id_toko: _currentIdToko,
    });
    if (error) { console.error('dbUpsertProfile:', error); return null; }
    return data; // returns the bigint id
}

async function dbDeactivateProfile(id) {
    const { error } = await _sb.rpc('deactivate_profile', { p_id: Number(id), p_id_toko: _currentIdToko });
    if (error) console.error('dbDeactivateProfile:', error);
    return !error;
}

// ── QR LOGIN ──────────────────────────────────────────────────────────────────
async function dbGenerateQrToken() {
    const { data, error } = await _sb.rpc('generate_qr_token');
    if (error) { console.error('dbGenerateQrToken:', error); return null; }
    return data;
}

async function dbCheckQrStatus(token) {
    const { data, error } = await _sb.rpc('check_qr_status', { p_token: token });
    if (error) { console.error('dbCheckQrStatus:', error); return null; }
    return data;
}

// ── LOAD ALL (called after login) ────────────────────────────────────────────
async function dbLoadAll() {
    if (!_currentIdToko) return false;
    try {
        const [products, members, transactions, kategori, profiles] = await Promise.all([
            dbLoadProducts(),
            dbLoadMembers(),
            dbLoadTransactions(),
            dbLoadKategori(),
            dbLoadProfiles(),
        ]);

        // Merge into local DATA_ arrays
        DATA_BARANG.length = 0;
        for (const r of products) {
            const katNama = r.kategori ?? '';
            DATA_BARANG.push({
                id: r.id?.toString() ?? '',
                kode: r.kode ?? '',
                nama: r.nama,
                kategori: katNama,
                satuan: r.satuan ?? 'Pcs',
                hargaBeli: r.harga_beli ?? 0,
                hargaJual: r.harga_jual,
                stok: r.stok,
                stokMin: r.stok_minimum ?? 10,
                barcode: r.barcode ?? '',
                status: r.status ?? 'Aktif',
                fotoUrl: r.foto_url ?? null,
            });
        }

        DATA_MEMBER.length = 0;
        for (const r of members) {
            DATA_MEMBER.push({
                id: r.id?.toString() ?? '',
                nama: r.nama,
                hp: r.no_hp ?? '',
                email: r.email ?? '',
                alamat: r.alamat ?? '',
                totalBelanja: r.total_spend ?? 0,
                poin: r.poin ?? 0,
                tier: r.tier ?? '',
                status: r.aktif === false ? 'Non-aktif' : 'Aktif',
            });
        }

        DATA_PENJUALAN.length = 0;
        for (const r of transactions) {
            DATA_PENJUALAN.push({
                id: r.no_faktur ?? r.id?.toString() ?? '',
                dbId: r.id?.toString() ?? '',
                tanggal: r.tanggal ?? '',
                jam: (r.jam ?? '').slice(0, 5),
                kasir: r.kasir ?? '',
                pelanggan: r.pelanggan ?? 'Umum',
                metode: r.metode_bayar ?? '',
                total: r.total,
                terbayar: r.terbayar ?? 0,
                jatuhTempo: r.jatuh_tempo ?? '',
                status: r.status ?? 'Lunas',
                idReseller: r.id_reseller?.toString() ?? null,
                items: Array.isArray(r.transaksi_item) ?
                    r.transaksi_item.map(i => ({
                        nama: i.nama_produk ?? '',
                        harga: i.harga ?? 0,
                        qty: i.qty ?? 0,
                    })) : [],
            });
        }

        DATA_KATEGORI.length = 0;
        for (const r of kategori) {
            DATA_KATEGORI.push({
                id: r.id?.toString() ?? '',
                kode: r.kode ?? '',
                nama: r.nama,
                deskripsi: r.deskripsi ?? '',
                status: r.status ?? 'Aktif',
            });
        }

        DATA_USERS.length = 0;
        for (const p of profiles) {
            DATA_USERS.push({
                id: p.id?.toString() ?? '',
                nama: p.nama,
                username: p.username,
                role: p.role,
                status: p.aktif === false ? 'Non-aktif' : 'Aktif',
                lastLogin: '—',
                avatar: p.nama?.[0]?.toUpperCase() ?? '?',
                avatarColor: p.avatar_color ?? '#16A34A',
            });
        }

        return true;
    } catch (e) {
        console.warn('Supabase load failed:', e);
        return false;
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAMBAHAN v1.1 — entitas yang sebelumnya belum punya lapisan database sama
//  sekali (supplier, cabang, reseller, pembelian, retur, kas, opname, adjustment,
//  dan cicilan hutang/piutang).
//
//  Catatan: tabel-tabel ini membutuhkan MIGRASI v2.1 agar terfilter per toko.
//  Jalankan blok MIGRASI v2.1 di schema.sql sebelum menggunakan fitur ini
//  di lingkungan multi-toko. Sebelum migrasi, data ditampilkan tanpa filter.
// ══════════════════════════════════════════════════════════════════════════════

const _isDbId = (v) => v !== null && v !== undefined && v !== '' && !isNaN(Number(v));

// ── SUPPLIER ──────────────────────────────────────────────────────────────────
async function dbLoadSuppliers() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('supplier')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('id');
    if (error) throw error;
    return data;
}

async function dbUpsertSupplier(s) {
    const isNew = !_isDbId(s.id);
    const base = { nama: s.nama, kontak: s.kontak, alamat: s.alamat, email: s.email, status: s.status };
    if (isNew) {
        if (!_currentIdToko) throw new Error('Sesi tidak valid. Silakan login ulang.');
        const { data, error } = await _sb.from('supplier')
            .insert({ ...base, kode: 'SUP-' + Date.now(), id_toko: _currentIdToko })
            .select('id').single();
        if (error) { console.error('dbUpsertSupplier insert:', error); return null; }
        return data?.id?.toString() ?? null;
    } else {
        const { data, error } = await _sb.from('supplier')
            .update(base).eq('id', Number(s.id)).select('id').single();
        if (error) { console.error('dbUpsertSupplier update:', error); return null; }
        return data?.id?.toString() ?? null;
    }
}

async function dbDeleteSupplier(id) {
    if (!_isDbId(id)) return true;
    const { error } = await _sb.from('supplier').delete().eq('id', Number(id));
    if (error) { console.error('dbDeleteSupplier:', error); return false; }
    return true;
}

// ── CABANG ────────────────────────────────────────────────────────────────────
async function dbLoadCabang() {
    if (!_currentIdToko) return [];
    const q = _sb.from('cabang').select('*').order('id');
    const { data, error } = await q.eq('id_toko', _currentIdToko);
    if (error) throw error;
    return data;
}

async function dbUpsertCabang(c) {
    const isNew = !_isDbId(c.id);
    const base = { nama: c.nama, alamat: c.alamat, kontak: c.kontak, pic: c.pic, aktif: c.status !== 'Non-aktif' };
    if (isNew) {
        if (!_currentIdToko) throw new Error('Sesi tidak valid. Silakan login ulang.');
        const { data, error } = await _sb.from('cabang')
            .insert({ ...base, kode: 'CBG-' + Date.now(), id_toko: _currentIdToko })
            .select('id').single();
        if (error) { console.error('dbUpsertCabang insert:', error); return null; }
        return data?.id?.toString() ?? null;
    } else {
        const { data, error } = await _sb.from('cabang')
            .update(base).eq('id', Number(c.id)).select('id').single();
        if (error) { console.error('dbUpsertCabang update:', error); return null; }
        return data?.id?.toString() ?? null;
    }
}

async function dbDeleteCabang(id) {
    if (!_isDbId(id)) return true;
    const { error } = await _sb.from('cabang').delete().eq('id', Number(id));
    if (error) { console.error('dbDeleteCabang:', error); return false; }
    return true;
}

// ── RESELLER ──────────────────────────────────────────────────────────────────
async function dbLoadReseller() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('reseller')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('id');
    if (error) throw error;
    return data;
}

async function dbUpsertReseller(r) {
    const isNew = !_isDbId(r.id);
    const base = { nama: r.nama, no_hp: r.hp, alamat: r.alamat, diskon_pct: r.diskon, limit_kredit: r.limitKredit, aktif: r.status !== 'Non-aktif' };
    if (isNew) {
        if (!_currentIdToko) throw new Error('Sesi tidak valid. Silakan login ulang.');
        const { data, error } = await _sb.from('reseller')
            .insert({ ...base, kode: 'RSL-' + Date.now(), id_toko: _currentIdToko })
            .select('id').single();
        if (error) { console.error('dbUpsertReseller insert:', error); return null; }
        return data?.id?.toString() ?? null;
    } else {
        const { data, error } = await _sb.from('reseller')
            .update(base).eq('id', Number(r.id)).select('id').single();
        if (error) { console.error('dbUpsertReseller update:', error); return null; }
        return data?.id?.toString() ?? null;
    }
}

async function dbDeleteReseller(id) {
    if (!_isDbId(id)) return true;
    const { error } = await _sb.from('reseller').delete().eq('id', Number(id));
    if (error) { console.error('dbDeleteReseller:', error); return false; }
    return true;
}

// ── PEMBELIAN (sekaligus sumber data HUTANG) ─────────────────────────────────
async function dbLoadPembelian() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('pembelian')
        .select('*, supplier(nama)')
        .eq('id_toko', _currentIdToko)
        .order('tanggal', { ascending: false })
        .limit(500);
    if (error) throw error;
    return data;
}

async function dbUpsertPembelian(p) {
    const isNew = !_isDbId(p.id);
    const sup = DATA_SUPPLIER.find(s => s.nama === p.supplier);
    const payload = {
        tanggal: p.tanggal,
        total: p.total,
        status: p.status,
        terbayar: p.terbayar ?? 0,
        jatuh_tempo: p.jatuhTempo || null,
        keterangan: p.keterangan || null,
        id_supplier: sup && _isDbId(sup.id) ? Number(sup.id) : null,
    };
    if (!isNew) payload.id = Number(p.id);
    if (isNew) {
        payload.no_faktur = p.noFaktur || ('PO-' + Date.now());
        if (!_currentIdToko) throw new Error('Sesi tidak valid. Silakan login ulang.');
        payload.id_toko = _currentIdToko;
    }
    const { data, error } = await _sb.from('pembelian').upsert(payload).select('id').single();
    if (error) { console.error('dbUpsertPembelian:', error); return null; }
    return data?.id?.toString() ?? null;
}

async function dbDeletePembelian(id) {
    if (!_isDbId(id)) return true;
    const { error } = await _sb.from('pembelian').delete().eq('id', Number(id));
    if (error) { console.error('dbDeletePembelian:', error); return false; }
    return true;
}

async function dbInsertPembelianItems(idPembelian, items) {
    if (!_sb || !_isDbId(idPembelian) || !items?.length) return false;
    const rows = items.map(it => ({
        id_pembelian: Number(idPembelian),
        nama_produk: it.nama,
        qty: Number(it.qty),
        harga_satuan: Number(it.harga || 0),
    }));
    const { error } = await _sb.from('pembelian_item').insert(rows);
    if (error) { console.error('dbInsertPembelianItems:', error); return false; }
    return true;
}

async function dbLoadAllPembelianItems() {
    if (!_currentIdToko) return [];
    // Ambil via join pembelian agar hanya item milik toko ini
    const { data, error } = await _sb
        .from('pembelian_item')
        .select('*, pembelian!inner(id_toko)')
        .eq('pembelian.id_toko', _currentIdToko)
        .order('id_pembelian')
        .order('id');
    if (error) {
        // Fallback: jika join gagal (belum migrasi), load semua
        const { data: all, error: e2 } = await _sb.from('pembelian_item').select('*').order('id_pembelian').order('id');
        if (e2) { console.warn('dbLoadAllPembelianItems:', e2); return []; }
        return all ?? [];
    }
    return data ?? [];
}

// ── CICILAN HUTANG / PIUTANG ─────────────────────────────────────────────────
async function dbCatatPembayaran(jenis, induk, nominal, metode, tanggal) {
    if (!_currentIdToko) throw new Error('Sesi tidak valid. Silakan login ulang.');
    if (!_isDbId(induk.id)) return true;

    const { data, error } = await _sb.rpc('catat_cicilan', {
        p_jenis:        jenis,
        p_id_induk:     Number(induk.id),
        p_id_toko:      _currentIdToko,
        p_no_referensi: induk.noReferensi,
        p_terbayar:     induk.terbayar,
        p_status:       induk.status,
        p_nominal:      nominal,
        p_metode:       metode,
        p_tanggal:      tanggal,
    });
    if (error) { console.error('dbCatatPembayaran:', error); return false; }
    return data === true;
}

async function dbLoadPembayaran() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('pembayaran')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('id');
    if (error) {
        // Fallback jika kolom id_toko belum ada (belum migrasi v2.1)
        const { data: all, error: e2 } = await _sb.from('pembayaran').select('*').order('id');
        if (e2) { console.warn('dbLoadPembayaran:', e2); return []; }
        return all ?? [];
    }
    return data ?? [];
}

// ── RETUR ─────────────────────────────────────────────────────────────────────
async function dbLoadReturJual() {
    if (!_currentIdToko) return [];
    const q = _sb.from('retur_penjualan').select('*').order('id', { ascending: false });
    const { data, error } = await q.eq('id_toko', _currentIdToko);
    if (error) throw error;
    return data;
}

async function dbUpsertReturJual(r) {
    const payload = {
        no_retur: r.id,
        no_faktur: r.faktur,
        pelanggan: r.pelanggan,
        tanggal: r.tanggal,
        alasan: r.alasan,
        total_retur: r.total,
        status: r.status,
    };
    if (_currentIdToko) payload.id_toko = _currentIdToko;
    let { data, error } = await _sb.from('retur_penjualan').upsert(payload, { onConflict: 'no_retur' }).select('id').single();
    if (error?.code === '42703') {
        // Migrasi v1.1 belum dijalankan — coba tanpa kolom v1.1
        const { no_faktur, pelanggan, id_toko, ...base } = payload;
        ({ data, error } = await _sb.from('retur_penjualan').upsert(base, { onConflict: 'no_retur' }).select('id').single());
    }
    if (error) { console.error('dbUpsertReturJual:', error); return null; }
    return data?.id?.toString() ?? null;
}

async function dbLoadReturBeli() {
    if (!_currentIdToko) return [];
    const q = _sb.from('retur_pembelian').select('*').order('id', { ascending: false });
    const { data, error } = await q.eq('id_toko', _currentIdToko);
    if (error) throw error;
    return data;
}

async function dbUpsertReturBeli(r) {
    const payload = {
        no_retur: r.id,
        no_po: r.faktur,
        supplier: r.supplier,
        tanggal: r.tanggal,
        alasan: r.alasan,
        total_retur: r.total,
        status: r.status,
    };
    if (_currentIdToko) payload.id_toko = _currentIdToko;
    let { data, error } = await _sb.from('retur_pembelian').upsert(payload, { onConflict: 'no_retur' }).select('id').single();
    if (error?.code === '42703') {
        // Migrasi v1.1 belum dijalankan — coba tanpa kolom v1.1
        const { no_po, supplier, id_toko, ...base } = payload;
        ({ data, error } = await _sb.from('retur_pembelian').upsert(base, { onConflict: 'no_retur' }).select('id').single());
    }
    if (error) { console.error('dbUpsertReturBeli:', error); return null; }
    return data?.id?.toString() ?? null;
}

// ── KAS ───────────────────────────────────────────────────────────────────────
async function dbLoadKas() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('kas_log')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('tanggal', { ascending: false })
        .order('jam', { ascending: false })
        .limit(500);
    if (error) throw error;
    return data;
}

async function dbInsertKas(k) {
    let idKasir = null;
    try {
        const user = typeof userSekarang === 'function' ? userSekarang() : null;
        const prof = user && Array.isArray(DATA_USERS) ?
            DATA_USERS.find(u => u.username === user.username) : null;
        if (prof && !isNaN(Number(prof.id))) idKasir = Number(prof.id);
    } catch {}

    const payload = {
        keterangan: k.keterangan,
        tanggal: k.tanggal,
        jam: k.jam,
        nominal: k.nominal,
        tipe: k.tipe,
        kasir: k.kasir || null,
        id_kasir: idKasir,
    };
    if (_currentIdToko) payload.id_toko = _currentIdToko;
    // Kalau ada shift aktif, tempelkan mutasi manual ini ke shift itu supaya
    // ikut terhitung di saldo/rekonsiliasi shift — lihat DATA_SHIFT_AKTIF.
    if (typeof DATA_SHIFT_AKTIF !== 'undefined' && DATA_SHIFT_AKTIF && _isDbId(DATA_SHIFT_AKTIF.id)) {
        payload.id_shift = Number(DATA_SHIFT_AKTIF.id);
    }
    const { data, error } = await _sb.from('kas_log').insert(payload).select('id').single();
    if (error) { console.error('dbInsertKas:', error); return null; }
    return data?.id?.toString() ?? null;
}

async function dbDeleteKas(id) {
    if (!_isDbId(id)) return true;
    const { error } = await _sb.from('kas_log').delete().eq('id', Number(id));
    if (error) { console.error('dbDeleteKas:', error); return false; }
    return true;
}

// ── STOCK OPNAME ──────────────────────────────────────────────────────────────
async function dbLoadOpname() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('stock_opname')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('id', { ascending: false });
    if (error) throw error;
    return data;
}

async function dbUpsertOpname(o) {
    const payload = {
        no_opname: o.id,
        tanggal: o.tanggal,
        catatan: o.catatan,
        petugas: o.petugas,
        jumlah_item: o.jumlahItem,
        selisih: o.selisih,
        status: o.status,
    };
    if (_currentIdToko) payload.id_toko = _currentIdToko;
    const { data, error } = await _sb.from('stock_opname').upsert(payload, { onConflict: 'no_opname' }).select('id').single();
    if (error) { console.error('dbUpsertOpname:', error); return null; }
    return data?.id?.toString() ?? null;
}

// ── ADJUSTMENT STOK ───────────────────────────────────────────────────────────
async function dbLoadAdjustment() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('adjustment_stok')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('id', { ascending: false })
        .limit(300);
    if (error) throw error;
    return data;
}

async function dbInsertAdjustment(a) {
    const prod = DATA_BARANG.find(b => b.nama === a.namaProduk);
    const payload = {
        id_produk: prod && _isDbId(prod.id) ? Number(prod.id) : null,
        nama_produk: a.namaProduk,
        stok_sistem: a.stokSistem,
        stok_fisik: a.stokFisik,
        keterangan: a.keterangan,
        petugas: a.petugas,
        tanggal: a.tanggal,
        id_opname: _isDbId(a.idOpname) ? Number(a.idOpname) : null,
    };
    if (_currentIdToko) payload.id_toko = _currentIdToko;
    const { data, error } = await _sb.from('adjustment_stok').insert(payload).select('id').single();
    if (error) { console.error('dbInsertAdjustment:', error); return null; }

    // Tulis ke stok_log (P2-4) — fire-and-forget, tidak boleh blokir alur utama
    dbInsertStokLog({ namaProduk: a.namaProduk, stokSebelum: a.stokSistem, stokSesudah: a.stokFisik, tipe: 'koreksi', referensi: null });

    return data?.id?.toString() ?? null;
}

// ── STOK LOG ──────────────────────────────────────────────────────────────────
async function dbInsertStokLog(data) {
    const _user = typeof userSekarang === 'function' ? userSekarang() : null;
    const _prof = _user && Array.isArray(DATA_USERS) ?
        DATA_USERS.find(u => u.username === _user.username) : null;
    const prod = DATA_BARANG.find(b => b.nama === data.namaProduk);
    const payload = {
        id_produk: prod && _isDbId(prod.id) ? Number(prod.id) : null,
        nama_produk: data.namaProduk,
        stok_sebelum: data.stokSebelum,
        stok_sesudah: data.stokSesudah,
        tipe: data.tipe,
        referensi: data.referensi ?? null,
        id_operator: _prof?.id ? Number(_prof.id) : null,
    };
    if (_currentIdToko) payload.id_toko = _currentIdToko;
    const { error } = await _sb.from('stok_log').insert(payload);
    if (error) console.warn('dbInsertStokLog:', error.code, error.message);
}

async function dbLoadStokLog() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('stok_log')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('created_at', { ascending: false })
        .limit(300);
    if (error) throw error;
    return data ?? [];
}

// ── SHIFT KASIR ───────────────────────────────────────────────────────────────
async function dbBukaShift(s) {
    const payload = {
        kasir_nama: s.kasirNama,
        modal_awal: s.modalAwal,
        status: 'buka',
        jam_buka: new Date().toISOString(),
        total_tunai: 0,
        kas_masuk: 0,
        kas_keluar: 0,
    };
    if (_currentIdToko) payload.id_toko = _currentIdToko;
    const { data, error } = await _sb.from('shift').insert(payload).select('id').single();
    if (error) { console.error('dbBukaShift:', error); return null; }
    return data?.id?.toString() ?? null;
}

async function dbShiftSaldo(id) {
    if (!_isDbId(id)) return null;
    const { data, error } = await _sb.rpc('fn_shift_saldo', { p_shift_id: Number(id) });
    if (error) { console.error('dbShiftSaldo:', error); return null; }
    return typeof data === 'number' ? data : null;
}

async function dbTutupShift(id, totalTunai, kasMasuk, kasKeluar, saldoAkhir, selisih) {
    if (!_isDbId(id)) return false;
    const { error } = await _sb.from('shift').update({
        status: 'tutup',
        jam_tutup: new Date().toISOString(),
        total_tunai: totalTunai,
        kas_masuk: kasMasuk,
        kas_keluar: kasKeluar,
        saldo_akhir: saldoAkhir,
        selisih: selisih,
    }).eq('id', Number(id));
    if (error) { console.error('dbTutupShift:', error); return false; }
    return true;
}

async function dbLoadShiftAktif() {
    if (!_currentIdToko) return null;
    const { data, error } = await _sb
        .from('shift')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .eq('status', 'buka')
        .order('jam_buka', { ascending: false })
        .limit(1);
    if (error) throw error;
    return data?.[0] ?? null;
}

async function dbLoadShiftList() {
    if (!_currentIdToko) return [];
    const { data, error } = await _sb
        .from('shift')
        .select('*')
        .eq('id_toko', _currentIdToko)
        .order('jam_buka', { ascending: false })
        .limit(100);
    if (error) throw error;
    return data ?? [];
}

// ── SINKRONISASI STOK ─────────────────────────────────────────────────────────
async function dbUpdateStok(produkId, stokBaru) {
    if (!_isDbId(produkId)) return false;
    const { error } = await _sb.from('produk').update({ stok: stokBaru }).eq('id', Number(produkId));
    if (error) { console.error('dbUpdateStok:', error); return false; }
    return true;
}

// ── LOAD ALL TAMBAHAN ─────────────────────────────────────────────────────────
async function dbLoadAllExtra() {
    const hasil = { ok: [], gagal: [] };

    const muat = async(nama, fn) => {
        try {
            await fn();
            hasil.ok.push(nama);
        } catch (e) {
            console.warn(`Lewati ${nama}:`, e?.message || e);
            hasil.gagal.push(nama);
        }
    };

    await muat('supplier', async() => {
        const rows = await dbLoadSuppliers();
        DATA_SUPPLIER.length = 0;
        for (const r of rows) {
            DATA_SUPPLIER.push({
                id: r.id?.toString() ?? '',
                nama: r.nama,
                kontak: r.kontak ?? '',
                alamat: r.alamat ?? '',
                email: r.email ?? '',
                status: r.status ?? 'Aktif',
            });
        }
    });

    await muat('cabang', async() => {
        const rows = await dbLoadCabang();
        DATA_CABANG.length = 0;
        for (const r of rows) {
            DATA_CABANG.push({
                id: r.id?.toString() ?? '',
                kode: r.kode ?? '',
                nama: r.nama,
                alamat: r.alamat ?? '',
                kontak: r.kontak ?? '',
                pic: r.pic ?? '',
                status: r.aktif === false ? 'Non-aktif' : 'Aktif',
            });
        }
    });

    await muat('reseller', async() => {
        const rows = await dbLoadReseller();
        DATA_RESELLER.length = 0;
        for (const r of rows) {
            DATA_RESELLER.push({
                id: r.id?.toString() ?? '',
                kode: r.kode ?? '',
                nama: r.nama,
                hp: r.no_hp ?? '',
                alamat: r.alamat ?? '',
                diskon: Number(r.diskon_pct ?? 0),
                limitKredit: Number(r.limit_kredit ?? 0),
                status: r.aktif === false ? 'Non-aktif' : 'Aktif',
            });
        }
    });

    await muat('pembelian', async() => {
        const [rows, allItems] = await Promise.all([
            dbLoadPembelian(),
            dbLoadAllPembelianItems(),
        ]);
        const itemsByPO = {};
        for (const it of allItems) {
            if (!itemsByPO[it.id_pembelian]) itemsByPO[it.id_pembelian] = [];
            itemsByPO[it.id_pembelian].push({ nama: it.nama_produk, qty: it.qty, harga: it.harga_satuan });
        }
        DATA_PEMBELIAN.length = 0;
        for (const r of rows) {
            DATA_PEMBELIAN.push({
                id: r.id?.toString() ?? '',
                noFaktur: r.no_faktur,
                supplier: r.supplier?.nama ?? '—',
                tanggal: r.tanggal ?? '',
                jatuhTempo: r.jatuh_tempo ?? '',
                total: r.total ?? 0,
                terbayar: r.terbayar ?? 0,
                status: r.status ?? 'Lunas',
                keterangan: r.keterangan ?? '',
                items: itemsByPO[r.id] ?? [],
            });
        }
    });

    await muat('retur-beli', async() => {
        const rows = await dbLoadReturBeli();
        DATA_RETUR_BELI.length = 0;
        for (const r of rows) {
            DATA_RETUR_BELI.push({
                id: r.no_retur,
                faktur: r.no_po ?? '—',
                supplier: r.supplier ?? '—',
                tanggal: r.tanggal ?? '',
                total: r.total_retur ?? 0,
                alasan: r.alasan ?? '',
                status: r.status ?? 'Diproses',
            });
        }
    });

    await muat('retur-jual', async() => {
        const rows = await dbLoadReturJual();
        DATA_RETUR_JUAL.length = 0;
        for (const r of rows) {
            DATA_RETUR_JUAL.push({
                id: r.no_retur,
                faktur: r.no_faktur ?? '—',
                pelanggan: r.pelanggan ?? '—',
                tanggal: r.tanggal ?? '',
                total: r.total_retur ?? 0,
                alasan: r.alasan ?? '',
                status: r.status ?? 'Diproses',
            });
        }
    });

    await muat('kas', async() => {
        const rows = await dbLoadKas();
        DATA_KAS.length = 0;
        for (const r of rows) {
            DATA_KAS.push({
                id: r.id?.toString() ?? '',
                keterangan: r.keterangan,
                tanggal: r.tanggal ?? '',
                jam: (r.jam ?? '').slice(0, 5),
                nominal: r.nominal ?? 0,
                tipe: r.tipe ?? 'masuk',
                kasir: r.kasir ?? '—',
                idShift: r.id_shift != null ? r.id_shift.toString() : null,
            });
        }
    });

    await muat('opname', async() => {
        const rows = await dbLoadOpname();
        DATA_OPNAME.length = 0;
        for (const r of rows) {
            DATA_OPNAME.push({
                id: r.no_opname,
                dbId: r.id != null ? r.id.toString() : null,
                tanggal: r.tanggal ?? '',
                petugas: r.petugas ?? '—',
                jumlahItem: r.jumlah_item ?? 0,
                selisih: r.selisih ?? 0,
                catatan: r.catatan ?? '',
                status: r.status ?? 'Draft',
            });
        }
    });

    await muat('adjustment', async() => {
        const rows = await dbLoadAdjustment();
        DATA_ADJ.length = 0;
        for (const r of rows) {
            DATA_ADJ.push({
                id: r.id?.toString() ?? '',
                tanggal: r.tanggal ?? '',
                namaProduk: r.nama_produk,
                stokSistem: r.stok_sistem ?? 0,
                stokFisik: r.stok_fisik ?? 0,
                selisih: r.selisih ?? 0,
                keterangan: r.keterangan ?? '',
                petugas: r.petugas ?? '—',
                idOpname: r.id_opname != null ? r.id_opname.toString() : null,
            });
        }
    });

    await muat('pembayaran', async() => {
        const rows = await dbLoadPembayaran();
        DATA_PEMBAYARAN.length = 0;
        for (const r of rows) {
            DATA_PEMBAYARAN.push({
                id: r.id?.toString() ?? '',
                jenis: r.jenis,
                ref: r.no_referensi,
                nominal: r.nominal ?? 0,
                metode: r.metode ?? 'Tunai',
                tanggal: r.tanggal ?? '',
            });
        }
    });

    await muat('stok_log', async() => {
        const rows = await dbLoadStokLog();
        DATA_STOK_LOG.length = 0;
        for (const r of rows) {
            DATA_STOK_LOG.push({
                id: r.id?.toString() ?? '',
                namaProduk: r.nama_produk,
                stokSebelum: r.stok_sebelum ?? 0,
                stokSesudah: r.stok_sesudah ?? 0,
                selisih: r.selisih ?? 0,
                tipe: r.tipe ?? '',
                referensi: r.referensi ?? '',
                tanggal: r.created_at ? r.created_at.slice(0, 10) : '',
            });
        }
    });

    await muat('shift', async() => {
        const _safeInt = v => Number.isFinite(Number(v)) ? Number(v) : 0;
        const _mapShiftRow = r => ({
            id: r.id?.toString() ?? '',
            kasirNama: r.kasir_nama ?? r.nama_kasir ?? '',
            tanggal: (r.jam_buka ?? r.waktu_buka) ? (r.jam_buka ?? r.waktu_buka).slice(0, 10) : '',
            waktuBuka: r.jam_buka ?? r.waktu_buka ?? null,
            waktuTutup: r.jam_tutup ?? r.waktu_tutup ?? null,
            modalAwal: _safeInt(r.modal_awal ?? r.kas_awal),
            totalTunai: _safeInt(r.total_tunai ?? r.total_penjualan),
            kasMasuk: _safeInt(r.kas_masuk),
            kasKeluar: _safeInt(r.kas_keluar),
            saldoAkhir: r.saldo_akhir != null ? _safeInt(r.saldo_akhir) : (r.kas_akhir != null ? _safeInt(r.kas_akhir) : null),
            selisih: r.selisih != null ? _safeInt(r.selisih) : null,
            status: (r.status ?? 'tutup').toLowerCase(),
        });
        const aktif = await dbLoadShiftAktif();
        DATA_SHIFT_AKTIF = aktif ? _mapShiftRow(aktif) : null;
        const listRows = await dbLoadShiftList();
        DATA_SHIFT_LIST.length = 0;
        for (const r of listRows) DATA_SHIFT_LIST.push(_mapShiftRow(r));
    });

    return hasil;
}
