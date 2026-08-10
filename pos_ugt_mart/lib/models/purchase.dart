class Supplier {
  final String id;
  final String nama;
  final String kontak;
  const Supplier({required this.id, required this.nama, required this.kontak});
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

List<Supplier> dummySuppliers = [
  const Supplier(id: '1', nama: 'PT Indofood Sukses Makmur', kontak: '021-12345678'),
  const Supplier(id: '2', nama: 'CV Maju Bersama', kontak: '0271-567890'),
  const Supplier(id: '3', nama: 'UD Sukses Makmur', kontak: '031-678901'),
  const Supplier(id: '4', nama: 'PT Aqua Golden Mississippi', kontak: '021-23456789'),
];

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
