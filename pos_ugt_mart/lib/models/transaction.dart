class CartItem {
  final String productId;
  final String nama;
  final int harga;
  int qty;

  CartItem({
    required this.productId,
    required this.nama,
    required this.harga,
    required this.qty,
  });

  int get subtotal => harga * qty;

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
  final int items;
  final String status;
  final String customer;
  final List<CartItem> cartItems;

  Transaction({
    required this.id,
    required this.tanggal,
    required this.jam,
    required this.metode,
    required this.total,
    required this.items,
    required this.status,
    required this.customer,
    required this.cartItems,
  });
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
