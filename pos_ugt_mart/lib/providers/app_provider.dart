import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import '../models/shift.dart';
import '../services/db_service.dart';

class AppProvider extends ChangeNotifier {
  // Auth
  String kasirName     = '';
  String kasirUsername = '';
  String kasirRole     = '';
  String storeName = 'UGT MART';
  bool isLoggedIn = false;
  DateTime? loginTime;

  // Subscription
  String idToko = '';
  String planToko = 'free';   // 'free' | 'premium'
  DateTime? planExpired;

  bool get isPremium =>
      planToko == 'premium' &&
      (planExpired == null || planExpired!.isAfter(DateTime.now()));

  // Cart
  final Map<String, CartItem> cart = {};

  // Checkout
  String? selectedCustomer;
  int discount = 0;
  String note = '';
  String paymentMethod = 'Tunai';
  String cashInput = '';
  String voucherCode = '';
  double taxRate = 0; // persentase PPN, 0 = tidak ada PPN

  bool get taxEnabled => taxRate > 0;

  // Last transaction
  Map<String, dynamic>? lastTransaction;
  Transaction? lastTrxObj;

  // Selected member/transaction for detail
  Member? selectedMember;
  Transaction? selectedTransaction;
  String? selectedMemberId;

  // Kas
  String kasType = 'masuk';

  // Shift
  Shift? activeShift;

  // Pengaturan Aplikasi
  bool roundUpEnabled = false;
  String terminalName = 'Terminal Kasir';
  String alamatToko = '';

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    roundUpEnabled = prefs.getBool('roundUp') ?? false;
    terminalName   = prefs.getString('terminalName') ?? 'Terminal Kasir';
    alamatToko     = prefs.getString('alamatToko') ?? '';
    taxRate        = prefs.getDouble('taxRate') ?? 0;
    storeName      = prefs.getString('storeName') ?? storeName;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('roundUp', roundUpEnabled);
    await prefs.setString('terminalName', terminalName);
    await prefs.setString('alamatToko', alamatToko);
    await prefs.setDouble('taxRate', taxRate);
    await prefs.setString('storeName', storeName);
  }

  // Last error (for debugging, accessible by UI)
  String lastError = '';

  // Toast
  String _toast = '';
  String get toast => _toast;

  void showToast(String msg) {
    _toast = msg;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 2400), () {
      _toast = '';
      notifyListeners();
    });
  }

  // Cart operations
  void addToCart(Product product) {
    if (product.stok <= 0) {
      showToast('Stok ${product.nama} habis!');
      return;
    }
    final currentQty = cart[product.id]?.qty ?? 0;
    if (currentQty >= product.stok) {
      showToast('Stok tidak mencukupi (tersisa ${product.stok})');
      return;
    }
    if (cart.containsKey(product.id)) {
      cart[product.id]!.qty++;
    } else {
      cart[product.id] = CartItem(
        productId: product.id,
        nama: product.nama,
        harga: product.harga,
        qty: 1,
      );
    }
    notifyListeners();
    showToast('${product.nama} ditambahkan');
  }

  void incrementCart(String productId) {
    if (!cart.containsKey(productId)) return;
    final idx = dummyProducts.indexWhere((p) => p.id == productId);
    if (idx >= 0 && cart[productId]!.qty >= dummyProducts[idx].stok) {
      showToast('Stok tidak mencukupi (tersisa ${dummyProducts[idx].stok})');
      return;
    }
    cart[productId]!.qty++;
    notifyListeners();
  }

  void decrementCart(String productId) {
    if (cart.containsKey(productId)) {
      if (cart[productId]!.qty <= 1) {
        cart.remove(productId);
      } else {
        cart[productId]!.qty--;
      }
      notifyListeners();
    }
  }

  void clearCart() {
    cart.clear();
    discount = 0;
    note = '';
    cashInput = '';
    selectedCustomer = null;
    selectedMemberId = null;
    notifyListeners();
    showToast('Keranjang dikosongkan');
  }

  int get cartItemCount => cart.values.fold(0, (s, i) => s + i.qty);
  bool get hasCart => cart.isNotEmpty;

  int get subtotal => cart.values.fold(0, (s, i) => s + i.subtotal);
  int get taxValue => taxRate > 0 ? ((subtotal - discount) * taxRate / 100).round() : 0;

  int get total {
    final sub = subtotal - discount;
    final withTax = taxRate > 0 ? (sub * (1 + taxRate / 100)).round() : sub;
    if (roundUpEnabled && withTax > 0) return ((withTax / 100).ceil() * 100);
    return withTax;
  }

  int get roundUpValue {
    if (!roundUpEnabled) return 0;
    final sub = subtotal - discount;
    final withTax = taxRate > 0 ? (sub * (1 + taxRate / 100)).round() : sub;
    return total - withTax;
  }

  // Payment
  void setPaymentMethod(String method) {
    paymentMethod = method;
    notifyListeners();
  }

  void setCashInput(String value) {
    cashInput = value;
    notifyListeners();
  }

  int get cashAmount {
    final digits = cashInput.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }

  int get change => cashAmount - total;

  void processPayment() {
    final now = DateTime.now();
    final dateStr = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final todayPrefix = 'TRX-$idToko-$dateStr-';
    final id = '$todayPrefix${DbService.nextTrxSeq().toString().padLeft(3, '0')}';

    final points = selectedCustomer != null ? (total / 1000).floor() : 0;

    if (selectedCustomer != null && selectedMemberId != null) {
      final idx = dummyMembers.indexWhere((m) => m.id == selectedMemberId);
      if (idx >= 0) {
        dummyMembers[idx].poin += points;
        dummyMembers[idx].spend += total;
        DbService.updateMemberPoints(
          dummyMembers[idx].id, dummyMembers[idx].poin, dummyMembers[idx].spend);
      }
    }

    for (final item in cart.values) {
      final idx = dummyProducts.indexWhere((p) => p.id == item.productId);
      if (idx >= 0) {
        dummyProducts[idx].stok = (dummyProducts[idx].stok - item.qty).clamp(0, 999999);
        // Stok di DB dikurangi oleh trigger fn_kurangi_stok_penjualan
        // saat INSERT transaksi_item — tidak perlu update manual.
      }
    }

    final cartSnapshot = cart.values
        .map((c) => CartItem(productId: c.productId, nama: c.nama, harga: c.harga, qty: c.qty))
        .toList();

    final tanggal = '${now.day.toString().padLeft(2, '0')} ${_bulan(now.month)} ${now.year}';
    final trx = Transaction(
      id: id,
      tanggal: tanggal,
      jam: timeStr,
      metode: paymentMethod,
      total: total,
      items: cartItemCount,
      status: 'Lunas',
      customer: selectedCustomer ?? 'Umum',
      cartItems: cartSnapshot,
    );
    dummyHistory.insert(0, trx);
    DbService.saveTransaction(trx, kasirName,
        diskon: discount, ppnRate: taxRate, ppnNominal: taxValue,
        terbayar: paymentMethod == 'Tunai' ? cashAmount : total,
        onError: (e) {
      debugPrint('[APP] Transaksi gagal disimpan ke server: $e');
      showToast('⚠ Transaksi tidak tersimpan ke server. Cek koneksi.');
    });

    lastTrxObj = trx;
    lastTransaction = {
      'id': id,
      'tanggal': tanggal,
      'time': timeStr,
      'total': total,
      'subtotal': subtotal,
      'discount': discount,
      'taxRate': taxRate,
      'taxValue': taxValue,
      'roundUp': roundUpValue,
      'method': paymentMethod,
      'cash': paymentMethod == 'Tunai' ? cashAmount : total,
      'change': paymentMethod == 'Tunai' ? change : 0,
      'customer': selectedCustomer ?? 'Umum',
      'points': points,
      'note': note,
      'kasir': kasirName,
      'storeName': storeName,
      'alamat': alamatToko,
      'terminal': terminalName,
    };
  }

  String _bulan(int m) {
    const b = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return b[m - 1];
  }

  void startNewTransaction() {
    cart.clear();
    discount = 0;
    note = '';
    cashInput = '';
    voucherCode = '';
    selectedCustomer = null;
    selectedMemberId = null;
    paymentMethod = 'Tunai';
    lastTransaction = null;
    notifyListeners();
  }

  void setDiscount(int amount) {
    discount = amount < 0 ? 0 : amount;
    notifyListeners();
    showToast(discount > 0 ? 'Diskon diterapkan' : 'Diskon dihapus');
  }

  void setTaxRate(double rate) {
    taxRate = rate < 0 ? 0 : (rate > 100 ? 100 : rate);
    notifyListeners();
    _saveSettings();
    showToast(taxRate > 0 ? 'PPN ${taxRate.toStringAsFixed(taxRate % 1 == 0 ? 0 : 1)}% diaktifkan' : 'PPN dinonaktifkan');
  }

  void setRoundUp(bool v) {
    roundUpEnabled = v;
    notifyListeners();
    _saveSettings();
    showToast(v ? 'Pembulatan harga diaktifkan' : 'Pembulatan harga dinonaktifkan');
  }

  void setTerminalName(String v) {
    terminalName = v.trim().isEmpty ? 'Terminal Kasir' : v.trim();
    notifyListeners();
    _saveSettings();
  }

  void setAlamatToko(String v) {
    alamatToko = v.trim();
    notifyListeners();
    _saveSettings();
  }

  void setStoreName(String v) {
    storeName = v.trim().isEmpty ? 'UGT MART' : v.trim();
    notifyListeners();
    _saveSettings();
  }

  void selectMember(Member m) {
    selectedMember = m;
    notifyListeners();
  }

  void useMemberForTransaction(Member m) {
    selectedCustomer = m.nama;
    selectedMemberId = m.id;
    notifyListeners();
    showToast('${m.nama} dipakai di transaksi ini');
  }

  Future<bool> addKategori(String nama, String deskripsi, String status) async {
    if (dummyKategori.contains(nama)) {
      lastError = 'Kategori "$nama" sudah ada di daftar';
      showToast(lastError);
      return false;
    }
    final err = await DbService.saveKategori(nama, deskripsi, status);
    if (err != null) {
      lastError = err;
      showToast('Gagal simpan kategori: $err');
      return false;
    }
    if (status == 'Aktif') dummyKategori.add(nama);
    notifyListeners();
    showToast('Kategori $nama berhasil ditambahkan');
    return true;
  }

  Future<bool> addProduct({
    required String nama,
    required String kategori,
    required int hargaBeli,
    required int hargaJual,
    required int stok,
    required int stokMin,
    required String barcode,
    required String status,
  }) async {
    final id = await DbService.saveProduct(
      nama: nama, kategori: kategori,
      hargaBeli: hargaBeli, hargaJual: hargaJual,
      stok: stok, stokMin: stokMin,
      barcode: barcode, status: status,
    );
    if (id == null || id.startsWith('ERROR:')) {
      lastError = id ?? 'id null (login mungkin belum selesai)';
      showToast('Gagal simpan: $lastError');
      return false;
    }
    dummyProducts.add(Product(
      id: id, nama: nama, kategori: kategori,
      harga: hargaJual, stok: stok, stokMin: stokMin, barcode: barcode,
    ));
    if (kategori.isNotEmpty && !dummyKategori.contains(kategori)) {
      dummyKategori.add(kategori);
    }
    notifyListeners();
    showToast('Produk $nama berhasil ditambahkan');
    return true;
  }

  Future<bool> editProduct({
    required String id,
    required String nama,
    required String kategori,
    required int hargaBeli,
    required int hargaJual,
    required int stok,
    required int stokMin,
    required String barcode,
    required String status,
  }) async {
    final ok = await DbService.updateProduct(
      id: id, nama: nama, kategori: kategori,
      hargaBeli: hargaBeli, hargaJual: hargaJual,
      stok: stok, stokMin: stokMin,
      barcode: barcode, status: status,
    );
    if (!ok) { lastError = 'updateProduct returned false'; showToast('Gagal mengupdate produk'); return false; }
    final idx = dummyProducts.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      if (status == 'Aktif') {
        dummyProducts[idx] = Product(
          id: id, nama: nama, kategori: kategori,
          harga: hargaJual, hargaBeli: hargaBeli,
          stok: stok, stokMin: stokMin, barcode: barcode, status: status,
        );
      } else {
        dummyProducts.removeAt(idx);
      }
    }
    notifyListeners();
    showToast('Produk $nama berhasil diperbarui');
    return true;
  }

  Future<bool> removeProduct(String id) async {
    final ok = await DbService.deleteProduct(id);
    if (!ok) { showToast('Gagal menghapus produk'); return false; }
    dummyProducts.removeWhere((p) => p.id == id);
    notifyListeners();
    showToast('Produk berhasil dihapus');
    return true;
  }

  // Today's transaction stats (computed from dummyHistory)
  int get todayTrxCount {
    final prefix = _todayPrefix();
    return dummyHistory.where((t) => t.id.startsWith(prefix)).length;
  }

  int get todayTotalPenjualan {
    final prefix = _todayPrefix();
    return dummyHistory
        .where((t) => t.id.startsWith(prefix) && t.status == 'Lunas')
        .fold(0, (s, t) => s + t.total);
  }

  int get todayTunaiTotal {
    final prefix = _todayPrefix();
    return dummyHistory
        .where((t) => t.id.startsWith(prefix) && t.metode == 'Tunai' && t.status == 'Lunas')
        .fold(0, (s, t) => s + t.total);
  }

  int get todayItemsCount {
    final prefix = _todayPrefix();
    return dummyHistory
        .where((t) => t.id.startsWith(prefix))
        .fold(0, (s, t) => s + t.items);
  }

  int get todaySkuCount {
    final prefix = _todayPrefix();
    final ids = <String>{};
    for (final t in dummyHistory.where((t) => t.id.startsWith(prefix))) {
      for (final c in t.cartItems) { ids.add(c.productId); }
    }
    return ids.length;
  }

  int get kemarinTotalPenjualan {
    final prefix = _kemarinPrefix();
    return dummyHistory
        .where((t) => t.id.startsWith(prefix) && t.status == 'Lunas')
        .fold(0, (s, t) => s + t.total);
  }

  String _todayPrefix() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'TRX-$idToko-$y$m$d';
  }

  String _kemarinPrefix() {
    final kemarin = DateTime.now().subtract(const Duration(days: 1));
    final y = kemarin.year.toString();
    final m = kemarin.month.toString().padLeft(2, '0');
    final d = kemarin.day.toString().padLeft(2, '0');
    return 'TRX-$idToko-$y$m$d';
  }

  String _prefixForDay(DateTime day) {
    final y = day.year.toString();
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'TRX-$idToko-$y$m$d';
  }

  // ─── Grafik data ─────────────────────────────────────────────────────────────

  // 7 hari terakhir — Free & Premium
  List<int> chartDataLast7Days() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final prefix = _prefixForDay(day);
      return dummyHistory
          .where((t) => t.id.startsWith(prefix) && t.status == 'Lunas')
          .fold(0, (s, t) => s + t.total);
    });
  }

  List<String> chartLabels7Days() {
    const names = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return names[day.weekday % 7];
    });
  }

  // 30 hari terakhir — Premium only
  List<int> chartDataLast30Days() {
    final now = DateTime.now();
    return List.generate(30, (i) {
      final day = now.subtract(Duration(days: 29 - i));
      final prefix = _prefixForDay(day);
      return dummyHistory
          .where((t) => t.id.startsWith(prefix) && t.status == 'Lunas')
          .fold(0, (s, t) => s + t.total);
    });
  }

  // 6 label untuk 30 hari (setiap 6 bar: index 0,5,10,15,20,29)
  List<String> chartLabels30Days() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final daysBack = i == 5 ? 0 : 29 - (i * 6);
      final day = now.subtract(Duration(days: daysBack));
      return '${day.day}/${day.month}';
    });
  }

  // ─── Shift getters ───────────────────────────────────────────────────────────

  int get shiftKasMasuk =>
      dummyKasLog.where((k) => k.tipe == 'masuk').fold(0, (s, k) => s + k.nominal);

  int get shiftKasKeluar =>
      dummyKasLog.where((k) => k.tipe == 'keluar').fold(0, (s, k) => s + k.nominal);

  int get shiftSaldoSeharusnya =>
      (activeShift?.modalAwal ?? 0) + todayTunaiTotal + shiftKasMasuk - shiftKasKeluar;

  Future<void> loadActiveShift() async {
    activeShift = await DbService.getActiveShift();
    notifyListeners();
  }

  Future<bool> bukaShift(int modalAwal) async {
    final shift = await DbService.bukaShift(modalAwal, kasirName);
    if (shift == null) return false;
    activeShift = shift;
    notifyListeners();
    return true;
  }

  Future<bool> tutupShift(int uangFisik) async {
    if (activeShift == null) return false;
    final tunai   = todayTunaiTotal;
    final kasIn   = shiftKasMasuk;
    final kasOut  = shiftKasKeluar;
    final selisih = uangFisik - shiftSaldoSeharusnya;
    final ok = await DbService.tutupShift(
      shiftId:    activeShift!.id,
      totalTunai: tunai,
      kasIn:      kasIn,
      kasOut:     kasOut,
      saldoAkhir: uangFisik,
      selisih:    selisih,
    );
    if (ok) {
      activeShift = null;
      notifyListeners();
    }
    return ok;
  }

  Future<void> refreshData() async {
    final idTokoInt = int.tryParse(idToko);
    if (idTokoInt == null) return;
    await Future.wait([
      DbService.loadAll(),
      DbService.loadSuppliers(),
      DbService.loadPurchases(),
      DbService.loadKategori(),
      DbService.loadKasLog(),
    ]);
    if (isPremium) activeShift = await DbService.getActiveShift();
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final result = await DbService.validateLogin(username, password);
    if (result == null) return false;
    kasirName     = result['nama'] ?? '';
    kasirUsername = username;
    kasirRole   = result['role'] ?? '';
    idToko      = result['id_toko'] ?? '';
    storeName   = result['nama_toko']?.isNotEmpty == true ? result['nama_toko']! : storeName;
    planToko    = result['plan'] ?? 'free';
    final exp   = result['expired_at'];
    planExpired = exp != null ? DateTime.tryParse(exp) : null;
    isLoggedIn  = true;
    loginTime   = DateTime.now();

    // Set id_toko ke DbService lalu load data milik toko ini
    final idTokoInt = int.tryParse(idToko);
    DbService.setToko(idTokoInt);
    if (idTokoInt != null) {
      await Future.wait([
        DbService.loadAll(),
        DbService.loadSuppliers(),
        DbService.loadPurchases(),
        DbService.loadKategori(),
        DbService.loadKasLog(),
      ]);
      if (isPremium) activeShift = await DbService.getActiveShift();
      DbService.setupRealtime(() async {
        await DbService.loadAll();
        notifyListeners();
      });
    }

    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    DbService.teardownRealtime();
    isLoggedIn       = false;
    kasirName        = '';
    kasirUsername    = '';
    kasirRole        = '';
    idToko           = '';
    planToko         = 'free';
    planExpired      = null;
    loginTime        = null;
    cart.clear();
    selectedCustomer = null;
    selectedMemberId = null;
    activeShift      = null;
    await DbService.clearLocalData();
    notifyListeners();
  }
}
