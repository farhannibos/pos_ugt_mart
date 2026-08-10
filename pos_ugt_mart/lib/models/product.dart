class Product {
  final String id;
  final String nama;
  final String kategori;
  final int harga;
  final int hargaBeli;
  int stok;
  final int stokMin;
  final String barcode;
  final String status;
  final String satuan;

  Product({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.harga,
    this.hargaBeli = 0,
    required this.stok,
    this.stokMin = 10,
    required this.barcode,
    this.status = 'Aktif',
    this.satuan = 'Pcs',
  });

  String get initials {
    final words = nama.split(' ');
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return nama.substring(0, 2).toUpperCase();
  }

  bool get isLowStock => stok <= stokMin;
}

final List<String> dummyKategori = [];

final List<Product> dummyProducts = [];
