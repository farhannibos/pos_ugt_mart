import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import '../models/purchase.dart';
import '../models/shift.dart';

final _db = Supabase.instance.client;

class DbService {
  static int? _idToko;
  static int _todayTrxCount = 0;
  static RealtimeChannel? _realtimeChannel;

  static void setToko(int? id) {
    _idToko = id;
    _todayTrxCount = 0;
  }

  static int nextTrxSeq() => ++_todayTrxCount;

  static void setupRealtime(Future<void> Function() onChanged) {
    if (_idToko == null || _realtimeChannel != null) return;
    _realtimeChannel = _db
        .channel('mobile-toko-$_idToko')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produk',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_toko',
            value: _idToko!,
          ),
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transaksi',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_toko',
            value: _idToko!,
          ),
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'member',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_toko',
            value: _idToko!,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  static void teardownRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  static Future<void> loadKategori() async {
    if (_idToko == null) return;
    try {
      // Filter kategori milik toko ini ATAU kategori global (id_toko IS NULL)
      // Butuh kolom id_toko di tabel kategori (jalankan migration_kategori_id_toko.sql)
      final rows = await _db
          .from('kategori')
          .select('nama')
          .or('id_toko.eq.$_idToko,id_toko.is.null')
          .eq('status', 'Aktif')
          .order('nama');
      dummyKategori.clear();
      for (final r in rows) {
        dummyKategori.add(r['nama'] as String);
      }
      debugPrint('[DB] loadKategori: ${dummyKategori.length} kategori loaded');
    } catch (e) {
      // Kolom id_toko mungkin belum ada — fallback: load semua kategori aktif
      debugPrint('[DB] loadKategori ERROR (id_toko filter): $e — retrying without filter');
      try {
        final rows = await _db
            .from('kategori')
            .select('nama')
            .eq('status', 'Aktif')
            .order('nama');
        dummyKategori.clear();
        for (final r in rows) {
          dummyKategori.add(r['nama'] as String);
        }
        debugPrint('[DB] loadKategori fallback: ${dummyKategori.length} kategori loaded');
      } catch (e2) {
        debugPrint('[DB] loadKategori fallback ERROR: $e2');
      }
    }
  }

  // Returns null on success, error string on failure.
  static Future<String?> saveKategori(String nama, String deskripsi, String status) async {
    if (_idToko == null) return 'Belum login (id_toko null)';
    // Generate kode dari nama (3 huruf kapital)
    final kode = nama.replaceAll(' ', '').toUpperCase().substring(0, nama.replaceAll(' ', '').length.clamp(1, 6));
    // Coba dari paling lengkap ke paling sederhana
    final attempts = <Map<String, dynamic>>[
      {'nama': nama, 'kode': kode, 'deskripsi': deskripsi, 'status': status, 'id_toko': _idToko},
      {'nama': nama, 'kode': kode, 'deskripsi': deskripsi, 'status': status},
      {'nama': nama, 'kode': kode, 'status': status},
    ];
    String lastErr = '';
    for (final data in attempts) {
      try {
        await _db.from('kategori').insert(data);
        debugPrint('[DB] saveKategori OK with keys: ${data.keys}');
        return null; // sukses
      } catch (e) {
        lastErr = e.toString();
        debugPrint('[DB] saveKategori attempt ${data.keys}: $e');
      }
    }
    return lastErr;
  }

  static Future<bool> loadAll() async {
    if (_idToko == null) { debugPrint('[DB] loadAll: _idToko null, skip'); return false; }
    debugPrint('[DB] loadAll: id_toko=$_idToko');
    try {
      await Future.wait([
        _loadProducts(),
        _loadMembers(),
        _loadHistory(),
      ]);
      debugPrint('[DB] loadAll: selesai, produk=${dummyProducts.length}');
      return true;
    } catch (e, st) {
      debugPrint('[DB] loadAll ERROR: $e\n$st');
      return false;
    }
  }

  static Future<void> _loadProducts() async {
    try {
      final rows = await _db
          .from('produk')
          .select('*')
          .eq('id_toko', _idToko!)
          .order('id');
      debugPrint('[DB] _loadProducts: ${rows.length} baris');
      dummyProducts.clear();
      for (final r in rows) {
        // kategori disimpan sebagai text (nama langsung), bukan FK integer
        final kat = r['kategori'];
        dummyProducts.add(Product(
          id:        r['id'].toString(),
          nama:      r['nama'] as String,
          kategori:  (kat is String ? kat : ''),
          harga:     (r['harga_jual'] ?? r['harga'] ?? 0) as int,
          hargaBeli: r['harga_beli'] as int? ?? 0,
          stok:      r['stok'] as int,
          stokMin:   r['stok_minimum'] as int? ?? 10,
          barcode:   r['barcode'] as String? ?? '',
          status:    r['status'] as String? ?? 'Aktif',
          satuan:    r['satuan'] as String? ?? 'Pcs',
        ));
      }
    } catch (e) {
      debugPrint('[DB] _loadProducts ERROR: $e');
      rethrow;
    }
  }

  static Future<bool> updateProduct({
    required String id,
    required String nama,
    required String kategori,
    required int hargaBeli,
    required int hargaJual,
    required int stok,
    required int stokMin,
    required String barcode,
    required String status,
    required String satuan,
  }) async {
    try {
      await _db.from('produk').update({
        'nama':         nama,
        'kategori':     kategori,
        'harga_beli':   hargaBeli,
        'harga_jual':   hargaJual,
        'stok':         stok,
        'stok_minimum': stokMin,
        'barcode':      barcode,
        'status':       status,
        'satuan':       satuan,
      }).eq('id', int.parse(id));
      return true;
    } catch (e) {
      debugPrint('[DB] updateProduct ERROR: $e');
      return false;
    }
  }

  static Future<bool> deleteProduct(String id) async {
    try {
      await _db.from('produk').delete().eq('id', int.parse(id));
      return true;
    } catch (e) {
      debugPrint('[DB] deleteProduct ERROR: $e');
      return false;
    }
  }

  static Future<void> _loadMembers() async {
    final rows = await _db
        .from('member')
        .select()
        .eq('id_toko', _idToko!)
        .order('id');
    dummyMembers.clear();
    for (final r in rows) {
      dummyMembers.add(Member(
        id:    r['id'].toString(),
        nama:  r['nama'] as String,
        hp:    r['no_hp'] as String? ?? '',
        poin:  r['poin'] as int? ?? 0,
        spend: r['total_spend'] as int? ?? 0,
      ));
    }
  }

  static Future<void> _loadHistory() async {
    final rows = await _db
        .from('transaksi')
        .select('*, transaksi_item(*)')
        .eq('id_toko', _idToko!)
        .order('created_at', ascending: false)
        .limit(100);
    dummyHistory.clear();
    for (final r in rows) {
      final items = (r['transaksi_item'] as List).map((i) => CartItem(
        productId: i['id_produk']?.toString() ?? '',
        nama:      i['nama_produk'] as String? ?? '',
        harga:     i['harga'] as int,
        qty:       i['qty'] as int,
      )).toList();
      dummyHistory.add(Transaction(
        id:       r['no_faktur'] as String? ?? r['id'].toString(),
        tanggal:  r['tanggal']?.toString() ?? '',
        jam:      r['jam']?.toString() ?? '',
        metode:   r['metode_bayar'] as String? ?? '',
        total:    r['total'] as int,
        items:    r['jumlah_item'] as int? ?? items.length,
        status:   r['status'] as String? ?? 'Lunas',
        customer: r['pelanggan'] as String? ?? 'Umum',
        cartItems: items,
      ));
    }
    // Fetch actual count of today's transactions from DB to avoid ID collision
    // when dummyHistory is capped at 100 rows.
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final countRows = await _db
        .from('transaksi')
        .select('id')
        .eq('id_toko', _idToko!)
        .gte('created_at', todayStr);
    _todayTrxCount = countRows.length;
  }

  static void saveTransaction(
    Transaction trx,
    String kasir, {
    int diskon = 0,
    double ppnRate = 0,
    int ppnNominal = 0,
    int? terbayar,
    void Function(String)? onError,
  }) {
    _saveTransactionAsync(trx, kasir,
        diskon: diskon, ppnRate: ppnRate, ppnNominal: ppnNominal,
        terbayar: terbayar, onError: onError);
  }

  static Future<void> _saveTransactionAsync(
    Transaction trx,
    String kasir, {
    int diskon = 0,
    double ppnRate = 0,
    int ppnNominal = 0,
    int? terbayar,
    void Function(String)? onError,
  }) async {
    if (_idToko == null) return;
    final iso = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final result = await _db.from('transaksi').insert({
        'id_toko':      _idToko,
        'no_faktur':    trx.id,
        'tanggal':      iso,
        'jam':          trx.jam,
        'kasir':        kasir,
        'pelanggan':    trx.customer,
        'metode_bayar': trx.metode,
        'total':        trx.total,
        'terbayar':     terbayar ?? trx.total,
        'jumlah_item':  trx.items,
        'status':       trx.status,
        'diskon':       diskon,
        'ppn_rate':     ppnRate,
        'ppn_nominal':  ppnNominal,
      }).select('id').single();

      final transaksiId = result['id'] as int;
      debugPrint('[DB] transaksi saved: id=$transaksiId no_faktur=${trx.id}');

      await Future.wait(trx.cartItems.map((item) =>
        _db.from('transaksi_item').insert({
          'id_transaksi': transaksiId,
          'id_produk':    int.tryParse(item.productId),
          'nama_produk':  item.nama,
          'harga':        item.harga,
          'qty':          item.qty,
        }),
      ));
    } catch (e) {
      debugPrint('[DB] _saveTransactionAsync ERROR: $e');
      onError?.call(e.toString());
    }
  }

  static Future<void> loadKasLog() async {
    if (_idToko == null) return;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await _db
          .from('kas_log')
          .select()
          .eq('id_toko', _idToko!)
          .eq('tanggal', today)
          .order('jam', ascending: false);
      dummyKasLog.clear();
      for (final r in rows) {
        dummyKasLog.add(KasLog(
          ket:     r['keterangan'] as String? ?? '',
          jam:     (r['jam'] as String? ?? '').substring(0, 5),
          nominal: r['nominal'] as int? ?? 0,
          tipe:    r['tipe'] as String? ?? 'masuk',
        ));
      }
    } catch (e) {
      debugPrint('[DB] loadKasLog ERROR: $e');
    }
  }

  static Future<void> saveKas(String ket, String tipe, int nominal, String kasir) async {
    if (_idToko == null) return;
    try {
      final now = DateTime.now();
      await _db.from('kas_log').insert({
        'id_toko':    _idToko,
        'keterangan': ket,
        'tipe':       tipe,
        'nominal':    nominal,
        'tanggal':    now.toIso8601String().substring(0, 10),
        'jam':        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'kasir':      kasir,
      });
    } catch (e) {
      debugPrint('[DB] saveKas ERROR: $e');
    }
  }

  static Future<String?> saveProduct({
    required String nama,
    required String kategori,
    required int hargaBeli,
    required int hargaJual,
    required int stok,
    required int stokMin,
    required String barcode,
    required String status,
    required String satuan,
  }) async {
    if (_idToko == null) {
      debugPrint('[DB] saveProduct: _idToko null, aborted');
      return null;
    }
    // Generate kode dari nama produk (3-6 huruf kapital) + timestamp singkat
    final namaClean = nama.replaceAll(' ', '').toUpperCase();
    final kode = 'PRD-${namaClean.substring(0, namaClean.length.clamp(1, 4))}-${DateTime.now().millisecondsSinceEpoch % 10000}';
    try {
      final result = await _db.from('produk').insert({
        'id_toko':      _idToko,
        'kode':         kode,
        'nama':         nama,
        'kategori':     kategori,
        'harga_beli':   hargaBeli,
        'harga_jual':   hargaJual,
        'stok':         stok,
        'stok_minimum': stokMin,
        'barcode':      barcode,
        'status':       status,
        'satuan':       satuan,
      }).select('id').single();
      debugPrint('[DB] saveProduct OK: id=${result['id']}');
      return result['id'].toString();
    } catch (e) {
      debugPrint('[DB] saveProduct ERROR: $e');
      return 'ERROR: $e'; // kembalikan pesan error agar UI bisa tampilkan
    }
  }

  static void updateMemberPoints(String memberId, int poin, int spend) {
    _db.from('member')
        .update({'poin': poin, 'total_spend': spend})
        .eq('id', int.tryParse(memberId) ?? 0)
        .then((_) {})
        .catchError((_) {});
  }

  // ── SUPPLIERS ──────────────────────────────────────────────────────────────
  static Future<void> loadSuppliers() async {
    if (_idToko == null) return;
    try {
      final rows = await _db
          .from('supplier')
          .select('id, kode, nama, kontak, alamat, email, status')
          .eq('id_toko', _idToko!)
          .order('nama');
      dummySuppliers.clear();
      for (final r in rows) {
        dummySuppliers.add(Supplier(
          id:     r['id'].toString(),
          kode:   r['kode'] as String? ?? '',
          nama:   r['nama'] as String,
          kontak: r['kontak'] as String? ?? '',
          alamat: r['alamat'] as String? ?? '',
          email:  r['email'] as String? ?? '',
          status: r['status'] as String? ?? 'Aktif',
        ));
      }
    } catch (e) {
      debugPrint('[DB] loadSuppliers ERROR: $e');
    }
  }

  static Future<String?> saveSupplier({
    required String nama,
    required String kontak,
    String alamat = '',
    String email = '',
    String status = 'Aktif',
  }) async {
    if (_idToko == null) return null;
    final namaClean = nama.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final prefix = namaClean.substring(0, namaClean.length.clamp(1, 4));
    final kode = 'SUP-$prefix-${DateTime.now().millisecondsSinceEpoch % 10000}';
    try {
      final result = await _db.from('supplier').insert({
        'id_toko': _idToko,
        'kode':    kode,
        'nama':    nama.trim(),
        'kontak':  kontak.trim(),
        'alamat':  alamat.trim(),
        'email':   email.trim(),
        'status':  status,
      }).select('id').single();
      debugPrint('[DB] saveSupplier OK: id=${result['id']}');
      return result['id'].toString();
    } catch (e) {
      debugPrint('[DB] saveSupplier ERROR: $e');
      return null;
    }
  }

  static Future<bool> updateSupplier({
    required String id,
    required String nama,
    required String kontak,
    String alamat = '',
    String email = '',
    String status = 'Aktif',
  }) async {
    try {
      await _db.from('supplier').update({
        'nama':   nama.trim(),
        'kontak': kontak.trim(),
        'alamat': alamat.trim(),
        'email':  email.trim(),
        'status': status,
      }).eq('id', int.parse(id));
      return true;
    } catch (e) {
      debugPrint('[DB] updateSupplier ERROR: $e');
      return false;
    }
  }

  static Future<bool> deleteSupplier(String id) async {
    try {
      await _db.from('supplier').delete().eq('id', int.parse(id));
      return true;
    } catch (e) {
      debugPrint('[DB] deleteSupplier ERROR: $e');
      return false;
    }
  }

  // ── PURCHASES ──────────────────────────────────────────────────────────────
  static Future<void> loadPurchases() async {
    if (_idToko == null) return;
    try {
      final rows = await _db
          .from('pembelian')
          .select('*, supplier(nama), pembelian_item(*)')
          .eq('id_toko', _idToko!)
          .order('created_at', ascending: false)
          .limit(50);
      dummyPurchases.clear();
      for (final r in rows) {
        final sup   = r['supplier'];
        final items = (r['pembelian_item'] as List).map((i) => PurchaseItem(
          productId:  '',
          namaProduk: i['nama_produk'] as String,
          qty:        i['qty'] as int,
          hargaBeli:  i['harga_beli'] as int? ?? 0,
        )).toList();
        dummyPurchases.add(Purchase(
          dbId:         r['id'] as int?,
          id:           r['no_faktur'] as String,
          supplierNama: sup is Map ? (sup['nama'] as String? ?? '') : '',
          tanggal:      r['tanggal']?.toString() ?? '',
          tanggalIso:   r['tanggal']?.toString() ?? '',
          jam:          r['created_at']?.toString().substring(11, 16) ?? '',
          total:        r['total'] as int,
          status:       r['status'] as String,
          terbayar:     r['terbayar'] as int? ?? 0,
          items:        items,
        ));
      }
    } catch (_) {}
  }

  static void savePurchase(Purchase purchase, String? supplierId, String operatorNama) {
    _savePurchaseAsync(purchase, supplierId, operatorNama);
  }

  static Future<void> _savePurchaseAsync(Purchase purchase, String? supplierId, String operatorNama) async {
    if (_idToko == null) return;
    try {
      final terbayarAwal = purchase.status == 'Lunas' ? purchase.total : 0;
      final result = await _db.from('pembelian').insert({
        'id_toko':   _idToko,
        'no_faktur': purchase.id,
        'tanggal':   purchase.tanggalIso,
        'total':     purchase.total,
        'status':    purchase.status,
        'terbayar':  terbayarAwal,
        if (supplierId != null) 'id_supplier': int.tryParse(supplierId),
      }).select('id').single();

      final pembelianId = result['id'] as int;
      purchase.dbId = pembelianId;
      purchase.terbayar = terbayarAwal;

      for (final item in purchase.items) {
        await _db.from('pembelian_item').insert({
          'id_pembelian': pembelianId,
          'nama_produk':  item.namaProduk,
          'harga_beli':   item.hargaBeli,
          'qty':          item.qty,
          if (item.productId.isNotEmpty) 'id_produk': int.tryParse(item.productId),
        });
        if (item.productId.isNotEmpty) {
          final prodIdx = dummyProducts.indexWhere((p) => p.id == item.productId);
          if (prodIdx >= 0) {
            await _db.from('produk')
                .update({'stok': dummyProducts[prodIdx].stok})
                .eq('id', int.parse(item.productId));
          }
        }
      }
    } catch (_) {}
  }

  // Catat pelunasan/cicilan hutang pembelian. Mengembalikan true jika berhasil,
  // dan langsung memutakhirkan `purchase.terbayar` & `purchase.status` (mutable).
  static Future<bool> catatCicilanHutang(Purchase purchase, int nominal) async {
    if (_idToko == null || purchase.dbId == null || nominal <= 0) return false;
    try {
      final newTerbayar = (purchase.terbayar + nominal).clamp(0, purchase.total);
      final newStatus = newTerbayar >= purchase.total ? 'Lunas' : 'Hutang';
      final now = DateTime.now();
      final tanggalIso =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final ok = await _db.rpc('catat_cicilan', params: {
        'p_jenis':        'hutang',
        'p_id_induk':     purchase.dbId,
        'p_id_toko':      _idToko,
        'p_no_referensi': purchase.id,
        'p_terbayar':     newTerbayar,
        'p_status':       newStatus,
        'p_nominal':      nominal,
        'p_metode':       'Tunai',
        'p_tanggal':      tanggalIso,
      }) as bool? ?? false;

      if (ok) {
        purchase.terbayar = newTerbayar;
        purchase.status = newStatus;
      }
      return ok;
    } catch (e) {
      debugPrint('[DB] catatCicilanHutang ERROR: $e');
      return false;
    }
  }

  // ─── Shift Kasir ────────────────────────────────────────────────────────────

  static Future<Shift?> getActiveShift() async {
    if (_idToko == null) return null;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await _db
          .from('shift')
          .select()
          .eq('id_toko', _idToko!)
          .eq('status', 'buka')
          .gte('jam_buka', today)
          .order('jam_buka', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final r = rows.first;
      return Shift(
        id:        r['id'] as int,
        kasirNama: r['kasir_nama'] as String? ?? '',
        modalAwal: r['modal_awal'] as int? ?? 0,
        jamBuka:   DateTime.parse(r['jam_buka'] as String).toLocal(),
        status:    r['status'] as String? ?? 'buka',
      );
    } catch (e) {
      debugPrint('[DB] getActiveShift ERROR: $e');
      return null;
    }
  }

  static Future<Shift?> bukaShift(int modalAwal, String kasirNama) async {
    if (_idToko == null) return null;
    try {
      final row = await _db.from('shift').insert({
        'id_toko':    _idToko,
        'kasir_nama': kasirNama,
        'modal_awal': modalAwal,
        'status':     'buka',
      }).select().single();
      return Shift(
        id:        row['id'] as int,
        kasirNama: row['kasir_nama'] as String? ?? kasirNama,
        modalAwal: row['modal_awal'] as int? ?? modalAwal,
        jamBuka:   DateTime.parse(row['jam_buka'] as String).toLocal(),
      );
    } catch (e) {
      debugPrint('[DB] bukaShift ERROR: $e');
      return null;
    }
  }

  static Future<bool> tutupShift({
    required int shiftId,
    required int totalTunai,
    required int kasIn,
    required int kasOut,
    required int saldoAkhir,
    required int selisih,
  }) async {
    try {
      await _db.from('shift').update({
        'status':      'tutup',
        'total_tunai': totalTunai,
        'kas_masuk':   kasIn,
        'kas_keluar':  kasOut,
        'saldo_akhir': saldoAkhir,
        'selisih':     selisih,
        'jam_tutup':   DateTime.now().toUtc().toIso8601String(),
      }).eq('id', shiftId);
      return true;
    } catch (e) {
      debugPrint('[DB] tutupShift ERROR: $e');
      return false;
    }
  }

  // Returns {nama, role, id_toko, nama_toko, plan, expired_at, nama_pemilik, ppn_rate, alamat, no_hp} or null.
  static Future<Map<String, dynamic>?> validateLogin(String username, String password) async {
    try {
      // Step 1: Validasi username/password via RPC (cek di tabel profiles)
      final data = await _db.rpc('validate_login', params: {
        'p_username': username,
        'p_password': password,
      }) as List;
      if (data.isEmpty) return null;
      final row = data[0];

      final idToko = row['id_toko']?.toString() ?? '';

      // Step 2: Login ke Supabase Auth supaya JWT punya id_toko (untuk RLS)
      final authEmail = '${username.toLowerCase().trim()}@ugtmart.internal';
      try {
        await _db.auth.signInWithPassword(email: authEmail, password: password);
      } on AuthException {
        // User belum ada di Supabase Auth — buat akun baru lalu login
        await _db.auth.signUp(
          email: authEmail,
          password: password,
          data: {
            'id_toko': row['id_toko'],
            'role':    row['role'],
            'nama':    row['nama'],
          },
        );
        await _db.auth.signInWithPassword(email: authEmail, password: password);
      }

      // Selalu update metadata supaya JWT punya id_toko terbaru
      // (mencakup kasus user lama yang dibuat sebelum metadata diset)
      await _db.auth.updateUser(UserAttributes(
        data: {
          'id_toko': row['id_toko'],
          'role':    row['role'],
          'nama':    row['nama'],
        },
      ));

      return {
        'nama':         row['nama']         as String? ?? '',
        'role':         row['role']         as String? ?? '',
        'id_toko':      idToko,
        'nama_toko':    row['nama_toko']    as String? ?? '',
        'plan':         row['plan']         as String? ?? 'free',
        'expired_at':   row['expired_at']?.toString() ?? '',
        'nama_pemilik': row['nama_pemilik'] as String? ?? '',
        'ppn_rate':     (row['ppn_rate'] as num?)?.toDouble() ?? 0.0,
        'alamat':       row['alamat']       as String? ?? '',
        'no_hp':        row['no_hp']        as String? ?? '',
        'qris_provider':    row['qris_provider']    as String? ?? '',
        'qris_atas_nama':   row['qris_atas_nama']   as String? ?? '',
        'qris_no_hp':       row['qris_no_hp']       as String? ?? '',
        'qris_image_url':   row['qris_image_url']   as String? ?? '',
        'bank_nama':        row['bank_nama']        as String? ?? '',
        'bank_no_rekening': row['bank_no_rekening'] as String? ?? '',
        'bank_atas_nama':   row['bank_atas_nama']   as String? ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateTokoSettings({
    required int idToko,
    required String namaToko,
    required String namaPemilik,
    required String alamat,
    required String noHp,
    required double ppnRate,
  }) async {
    try {
      await _db.rpc('update_toko_settings', params: {
        'p_id_toko':      idToko,
        'p_nama_toko':    namaToko,
        'p_nama_pemilik': namaPemilik,
        'p_alamat':       alamat,
        'p_no_hp':        noHp,
        'p_ppn_rate':     ppnRate,
      });
      debugPrint('[DB] updateTokoSettings OK');
    } catch (e) {
      debugPrint('[DB] updateTokoSettings ERROR: $e');
    }
  }

  // Upload gambar QRIS ke Supabase Storage (bucket 'qris'), return public URL.
  static Future<String?> uploadQrisImage(Uint8List bytes, String fileExt) async {
    if (_idToko == null) return null;
    try {
      final path = '$_idToko/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await _db.storage.from('qris').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _db.storage.from('qris').getPublicUrl(path);
    } catch (e) {
      debugPrint('[DB] uploadQrisImage ERROR: $e');
      return null;
    }
  }

  static Future<bool> updateTokoQris({
    required int idToko,
    required String provider,
    required String atasNama,
    required String noHp,
    required String imageUrl,
  }) async {
    try {
      await _db.rpc('update_toko_qris', params: {
        'p_id_toko':        idToko,
        'p_qris_provider':  provider,
        'p_qris_atas_nama': atasNama,
        'p_qris_no_hp':     noHp,
        'p_qris_image_url': imageUrl,
      });
      debugPrint('[DB] updateTokoQris OK');
      return true;
    } catch (e) {
      debugPrint('[DB] updateTokoQris ERROR: $e');
      return false;
    }
  }

  static Future<bool> updateTokoRekening({
    required int idToko,
    required String bankNama,
    required String noRekening,
    required String atasNama,
  }) async {
    try {
      await _db.rpc('update_toko_rekening', params: {
        'p_id_toko':          idToko,
        'p_bank_nama':        bankNama,
        'p_bank_no_rekening': noRekening,
        'p_bank_atas_nama':   atasNama,
      });
      debugPrint('[DB] updateTokoRekening OK');
      return true;
    } catch (e) {
      debugPrint('[DB] updateTokoRekening ERROR: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> registerToko({
    required String namaToko,
    required String alamat,
    required String noHp,
    required String namaOwner,
    required String username,
    required String password,
  }) async {
    try {
      final res = await _db.rpc('register_toko', params: {
        'p_nama_toko': namaToko,
        'p_alamat':    alamat,
        'p_no_hp':     noHp,
        'p_nama':      namaOwner,
        'p_username':  username,
        'p_password':  password,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'ok': false, 'pesan': 'Terjadi kesalahan'};
    } catch (e) {
      return {'ok': false, 'pesan': e.toString()};
    }
  }

  // Bersihkan semua data lokal saat logout
  static Future<void> clearLocalData() async {
    _idToko = null;
    dummyProducts.clear();
    dummyKategori.clear();
    dummyHistory.clear();
    dummyMembers.clear();
    dummySuppliers.clear();
    dummyPurchases.clear();
    dummyKasLog.clear();
    try {
      await _db.auth.signOut();
    } catch (_) {}
  }
}
