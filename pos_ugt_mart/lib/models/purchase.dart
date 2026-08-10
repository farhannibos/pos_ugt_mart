class Supplier {
  final String id;
  final String kode;
  final String nama;
  final String kontak;
  final String alamat;
  final String email;
  final String status; // Aktif / Non-aktif

  const Supplier({
    required this.id,
    this.kode = '',
    required this.nama,
    this.kontak = '',
    this.alamat = '',
    this.email = '',
    this.status = 'Aktif',
  });
}

class PurchaseItem {
  final String productId;
  final String namaProduk;
  int qty;
  int hargaBeli;

  PurchaseItem({
    required this.productId,
    required this.namaProduk,
    required this.qty,
    required this.hargaBeli,
  });

  int get subtotal => hargaBeli * qty;
}

class Purchase {
  final String id; // no_faktur: PO-YYYYMMDD-NNN
  final String supplierNama;
  final String tanggal; // display: DD Bln YYYY
  final String tanggalIso; // YYYY-MM-DD for DB
  final String jam;
  final int total;
  final String status; // Lunas / Hutang
  final List<PurchaseItem> items;

  Purchase({
    required this.id,
    required this.supplierNama,
    required this.tanggal,
    required this.tanggalIso,
    required this.jam,
    required this.total,
    required this.status,
    required this.items,
  });
}

List<Supplier> dummySuppliers = [];

List<Purchase> dummyPurchases = [
  Purchase(
    id: 'PO-20260803-001',
    supplierNama: 'PT Indofood Sukses Makmur',
    tanggal: '03 Agu 2026',
    tanggalIso: '2026-08-03',
    jam: '09:15',
    total: 1350000,
    status: 'Lunas',
    items: [
      PurchaseItem(productId: 'BRG-001', namaProduk: 'Indomie Goreng 85g', qty: 200, hargaBeli: 2800),
      PurchaseItem(productId: 'BRG-003', namaProduk: 'Minyak Goreng Sania 2L', qty: 10, hargaBeli: 35000),
    ],
  ),
  Purchase(
    id: 'PO-20260801-002',
    supplierNama: 'CV Maju Bersama',
    tanggal: '01 Agu 2026',
    tanggalIso: '2026-08-01',
    jam: '14:30',
    total: 2800000,
    status: 'Hutang',
    items: [
      PurchaseItem(productId: 'BRG-002', namaProduk: 'Beras Ramos 5kg', qty: 40, hargaBeli: 60000),
      PurchaseItem(productId: 'BRG-006', namaProduk: 'Teh Pucuk Harum 350ml', qty: 100, hargaBeli: 4000),
    ],
  ),
];
