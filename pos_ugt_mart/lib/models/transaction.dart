class CartItem {
  final String productId;
  final String nama;
  final int harga;
  double qty;
  final String satuan;

  CartItem({
    required this.productId,
    required this.nama,
    required this.harga,
    required this.qty,
    this.satuan = 'Pcs',
  });

  bool get isBulk => const {'Kg', 'Gram', 'Liter', 'mL'}.contains(satuan);

  int get subtotal => (harga * qty).round();

  String get initials {
    final words = nama.split(' ');
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return nama.substring(0, 2).toUpperCase();
  }
}

class Transaction {
  final String id;
  final String tanggal;
  final String jam;
  final String metode;
  final int total;
  int terbayar;   // mutable: updated when piutang dilunasi
  final int items;
  String status;  // mutable: 'Lunas' | 'Piutang'
  final String customer;
  final List<CartItem> cartItems;

  Transaction({
    required this.id,
    required this.tanggal,
    required this.jam,
    required this.metode,
    required this.total,
    this.terbayar = 0,
    required this.items,
    required this.status,
    required this.customer,
    required this.cartItems,
  });

  int get sisaPiutang => total - terbayar;
}

class KasLog {
  final String ket;
  final String jam;
  final int nominal;
  final String tipe;

  const KasLog({
    required this.ket,
    required this.jam,
    required this.nominal,
    required this.tipe,
  });
}

final List<Transaction> dummyHistory = [];

final List<KasLog> dummyKasLog = [];
