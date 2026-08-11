import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../widgets/ugt_widgets.dart';
import 'cart_screen.dart';
import 'barcode_scanner_screen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'Semua';

  void _showAddProductSheet(BuildContext context) {
    final namaCtrl      = TextEditingController();
    final hargaBeliCtrl = TextEditingController();
    final hargaJualCtrl = TextEditingController();
    final stokCtrl      = TextEditingController(text: '0');
    final stokMinCtrl   = TextEditingController(text: '10');
    final barcodeCtrl   = TextEditingController();
    final satuanLainCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedKategori = dummyKategori.isNotEmpty ? dummyKategori.first : '';
    String selectedStatus   = 'Aktif';
    String selectedSatuan   = 'Pcs';
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Tambah Produk Baru',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                          const SizedBox(height: 2),
                          Text('Isi data produk untuk ditambahkan ke daftar',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim)),
                          const SizedBox(height: 18),

                          _fieldLabel('Nama Produk'),
                          TextFormField(
                            controller: namaCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            decoration: _inputDeco('Contoh: Indomie Goreng'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama produk wajib diisi' : null,
                          ),
                          const SizedBox(height: 14),

                          _fieldLabel('Kategori'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: dummyKategori.isEmpty
                                  ? GestureDetector(
                                      onTap: () => _addKategoriInline(
                                        ctx, setSheet, (n) => selectedKategori = n),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: AppColors.bg,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text('Belum ada kategori — ketuk + untuk tambah',
                                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim)),
                                      ),
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: dummyKategori.contains(selectedKategori) ? selectedKategori : dummyKategori.first,
                                      decoration: _inputDeco('Pilih kategori'),
                                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                                      items: dummyKategori.map((k) =>
                                        DropdownMenuItem(value: k, child: Text(k))).toList(),
                                      onChanged: (v) => setSheet(() => selectedKategori = v ?? ''),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Kategori wajib dipilih' : null,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _addKategoriInline(
                                  ctx, setSheet, (n) => setSheet(() => selectedKategori = n)),
                                child: Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primaryMid),
                                  ),
                                  child: const Icon(Icons.add, color: AppColors.primaryDark, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _fieldLabel('Harga Beli'),
                              TextFormField(
                                controller: hargaBeliCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                                decoration: _inputDeco('0', prefix: 'Rp'),
                              ),
                            ])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _fieldLabel('Harga Jual'),
                              TextFormField(
                                controller: hargaJualCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                                decoration: _inputDeco('0', prefix: 'Rp'),
                              ),
                            ])),
                          ]),
                          const SizedBox(height: 14),

                          Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _fieldLabel('Stok'),
                              TextFormField(
                                controller: stokCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                                decoration: _inputDeco('0'),
                              ),
                            ])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _fieldLabel('Stok Minimum'),
                              TextFormField(
                                controller: stokMinCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                                decoration: _inputDeco('10'),
                              ),
                            ])),
                          ]),
                          const SizedBox(height: 14),

                          _fieldLabel('Satuan'),
                          DropdownButtonFormField<String>(
                            value: selectedSatuan,
                            decoration: _inputDeco('Pilih satuan'),
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            items: ['Pcs', 'Kg', 'Botol', 'Karung', 'Box', 'Liter', 'Lusin', 'Lainnya...']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setSheet(() => selectedSatuan = v ?? 'Pcs'),
                          ),
                          if (selectedSatuan == 'Lainnya...') ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: satuanLainCtrl,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                              decoration: _inputDeco('Ketik satuan, contoh: Kaleng, Gram'),
                              validator: (v) => (selectedSatuan == 'Lainnya...' && (v == null || v.trim().isEmpty))
                                ? 'Satuan tidak boleh kosong' : null,
                            ),
                          ],
                          const SizedBox(height: 14),

                          _fieldLabel('Barcode (opsional)'),
                          TextFormField(
                            controller: barcodeCtrl,
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            decoration: _inputDeco('Scan atau ketik barcode'),
                          ),
                          const SizedBox(height: 14),

                          _fieldLabel('Status'),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: _inputDeco(''),
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            items: ['Aktif', 'Non-aktif'].map((s) =>
                              DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setSheet(() => selectedStatus = v ?? 'Aktif'),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: Material(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: loading ? null : () async {
                                  if (!(formKey.currentState?.validate() ?? false)) return;
                                  if (selectedKategori.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Pilih atau tambah kategori terlebih dahulu')));
                                    return;
                                  }
                                  // Capture provider & data SEBELUM setSheet agar ctx tidak stale
                                  final prov   = ctx.read<AppProvider>();
                                  final nama   = namaCtrl.text.trim();
                                  final beli   = int.tryParse(hargaBeliCtrl.text) ?? 0;
                                  final jual   = int.tryParse(hargaJualCtrl.text) ?? 0;
                                  final stok   = int.tryParse(stokCtrl.text) ?? 0;
                                  final stokMn = int.tryParse(stokMinCtrl.text) ?? 10;
                                  final barc   = barcodeCtrl.text.trim();
                                  final kat    = selectedKategori;
                                  final stat   = selectedStatus;
                                  final sat    = selectedSatuan == 'Lainnya...'
                                    ? satuanLainCtrl.text.trim()
                                    : selectedSatuan;
                                  setSheet(() => loading = true);
                                  try {
                                    final ok = await prov.addProduct(
                                      nama: nama, kategori: kat,
                                      hargaBeli: beli, hargaJual: jual,
                                      stok: stok, stokMin: stokMn,
                                      barcode: barc, status: stat, satuan: sat,
                                    );
                                    if (!ok && ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Gagal simpan: ${prov.lastError}')));
                                      setSheet(() => loading = false);
                                      return;
                                    }
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                    if (ok && mounted) setState(() {});
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Error: $e')));
                                    }
                                    setSheet(() => loading = false);
                                  }
                                },
                                child: Center(
                                  child: loading
                                    ? const SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : Text('Simpan Produk',
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addKategoriInline(
    BuildContext ctx,
    StateSetter setSheet,
    void Function(String) onAdded,
  ) async {
    final namaCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final prov = ctx.read<AppProvider>(); // capture sebelum async gap

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Tambah Kategori',
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nama Kategori *',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 7),
            TextField(
              controller: namaCtrl,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
              decoration: _inputDeco('Contoh: Minuman, Sembako'),
            ),
            const SizedBox(height: 12),
            Text('Deskripsi (opsional)',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 7),
            TextField(
              controller: descCtrl,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
              decoration: _inputDeco('Keterangan singkat'),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dCtx).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Text('Batal',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(dCtx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Simpan',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ],
      ),
    );

    if (confirmed != true) return;
    final nama = namaCtrl.text.trim();
    if (nama.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Nama kategori tidak boleh kosong')));
      }
      return;
    }
    final ok = await prov.addKategori(nama, descCtrl.text.trim(), 'Aktif');
    if (ok) {
      setSheet(() => onAdded(nama));
    } else if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(
          prov.lastError.isEmpty ? 'Gagal menyimpan kategori' : 'Gagal: ${prov.lastError}')));
    }
  }

  void _showProductActions(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              InitialsAvatar(text: product.initials, size: 40, fontSize: 13, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.nama, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text(formatRp(product.harga), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
              ])),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: 'Edit Produk',
              color: AppColors.primary,
              onTap: () {
                Navigator.of(ctx).pop();
                _showEditProductSheet(context, product);
              },
            ),
            _ActionTile(
              icon: Icons.delete_outline,
              label: 'Hapus Produk',
              color: AppColors.red,
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDelete(context, product);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Produk', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          'Yakin ingin menghapus "${product.nama}"? Tindakan ini tidak bisa dibatalkan.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<AppProvider>().removeProduct(product.id);
              setState(() {});
            },
            child: Text('Hapus', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditProductSheet(BuildContext context, Product product) {
    final namaCtrl      = TextEditingController(text: product.nama);
    final hargaBeliCtrl = TextEditingController(text: product.hargaBeli.toString());
    final hargaJualCtrl = TextEditingController(text: product.harga.toString());
    final stokMinCtrl   = TextEditingController(text: product.stokMin.toString());
    final barcodeCtrl   = TextEditingController(text: product.barcode);
    final formKey = GlobalKey<FormState>();
    String selectedKategori = product.kategori;
    String selectedStatus   = product.status;
    const satuanPreset = ['Pcs', 'Kg', 'Botol', 'Karung', 'Box', 'Liter', 'Lusin'];
    final isPreset = satuanPreset.contains(product.satuan);
    String selectedSatuan = isPreset ? product.satuan : 'Lainnya...';
    final satuanLainCtrl = TextEditingController(text: isPreset ? '' : product.satuan);
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Edit Produk',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                          const SizedBox(height: 2),
                          Text('Perbarui data produk',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim)),
                          const SizedBox(height: 18),

                          _fieldLabel('Nama Produk'),
                          TextFormField(
                            controller: namaCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            decoration: _inputDeco('Nama produk'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama produk wajib diisi' : null,
                          ),
                          const SizedBox(height: 14),

                          _fieldLabel('Kategori'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: dummyKategori.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.bg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(selectedKategori.isEmpty ? '-' : selectedKategori,
                                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.text)),
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: dummyKategori.contains(selectedKategori) ? selectedKategori : dummyKategori.first,
                                      decoration: _inputDeco('Pilih kategori'),
                                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                                      items: dummyKategori.map((k) =>
                                        DropdownMenuItem(value: k, child: Text(k))).toList(),
                                      onChanged: (v) => setSheet(() => selectedKategori = v ?? selectedKategori),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Kategori wajib dipilih' : null,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _addKategoriInline(
                                  ctx, setSheet, (n) => setSheet(() => selectedKategori = n)),
                                child: Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primaryMid),
                                  ),
                                  child: const Icon(Icons.add, color: AppColors.primaryDark, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _fieldLabel('Harga Beli'),
                              TextFormField(
                                controller: hargaBeliCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                                decoration: _inputDeco('0', prefix: 'Rp'),
                              ),
                            ])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _fieldLabel('Harga Jual'),
                              TextFormField(
                                controller: hargaJualCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                                decoration: _inputDeco('0', prefix: 'Rp'),
                              ),
                            ])),
                          ]),
                          const SizedBox(height: 14),

                          _fieldLabel('Stok Minimum'),
                          TextFormField(
                            controller: stokMinCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            decoration: _inputDeco('10'),
                          ),
                          const SizedBox(height: 14),

                          _fieldLabel('Satuan'),
                          DropdownButtonFormField<String>(
                            value: selectedSatuan,
                            decoration: _inputDeco('Pilih satuan'),
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            items: ['Pcs', 'Kg', 'Botol', 'Karung', 'Box', 'Liter', 'Lusin', 'Lainnya...']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setSheet(() => selectedSatuan = v ?? 'Pcs'),
                          ),
                          if (selectedSatuan == 'Lainnya...') ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: satuanLainCtrl,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                              decoration: _inputDeco('Ketik satuan, contoh: Kaleng, Gram'),
                              validator: (v) => (selectedSatuan == 'Lainnya...' && (v == null || v.trim().isEmpty))
                                ? 'Satuan tidak boleh kosong' : null,
                            ),
                          ],
                          const SizedBox(height: 14),

                          _fieldLabel('Barcode (opsional)'),
                          TextFormField(
                            controller: barcodeCtrl,
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            decoration: _inputDeco('Scan atau ketik barcode'),
                          ),
                          const SizedBox(height: 14),

                          _fieldLabel('Status'),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: _inputDeco(''),
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
                            items: ['Aktif', 'Non-aktif'].map((s) =>
                              DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setSheet(() => selectedStatus = v ?? 'Aktif'),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: Material(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: loading ? null : () async {
                                  if (!(formKey.currentState?.validate() ?? false)) return;
                                  // Capture provider & data SEBELUM setSheet agar ctx tidak stale
                                  final prov   = ctx.read<AppProvider>();
                                  final nama   = namaCtrl.text.trim();
                                  final beli   = int.tryParse(hargaBeliCtrl.text) ?? 0;
                                  final jual   = int.tryParse(hargaJualCtrl.text) ?? 0;
                                  final stokMn = int.tryParse(stokMinCtrl.text) ?? 10;
                                  final barc   = barcodeCtrl.text.trim();
                                  final kat    = selectedKategori;
                                  final stat   = selectedStatus;
                                  final sat    = selectedSatuan == 'Lainnya...'
                                    ? satuanLainCtrl.text.trim()
                                    : selectedSatuan;
                                  setSheet(() => loading = true);
                                  try {
                                    final ok = await prov.editProduct(
                                      id: product.id, nama: nama, kategori: kat,
                                      hargaBeli: beli, hargaJual: jual,
                                      stok: product.stok, stokMin: stokMn,
                                      barcode: barc, status: stat, satuan: sat,
                                    );
                                    if (!ok && ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Gagal update: ${prov.lastError}')));
                                      setSheet(() => loading = false);
                                      return;
                                    }
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                    if (ok && mounted) setState(() {});
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Error: $e')));
                                    }
                                    setSheet(() => loading = false);
                                  }
                                },
                                child: Center(
                                  child: loading
                                    ? const SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : Text('Simpan Perubahan',
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Product> get _filtered {
    final q = _query.toLowerCase();
    return dummyProducts.where((p) {
      final catOk = _category == 'Semua' || p.kategori == _category;
      final searchOk = q.isEmpty || p.nama.toLowerCase().contains(q) || p.barcode.contains(q);
      return catOk && searchOk;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final products = _filtered;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;
    final crossAxis = isWide ? (size.width ~/ 320).clamp(2, 4) : 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Daftar Produk',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                        const Spacer(),
                        // Tambah produk
                        GestureDetector(
                          onTap: () => _showAddProductSheet(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.add, size: 18, color: AppColors.primary),
                          ),
                        ),
                        // Scan icon
                        GestureDetector(
                          onTap: () async {
                            final result = await Navigator.of(context).push<dynamic>(
                              MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                            );
                            if (!context.mounted || result == null) return;
                            if (result is Product) {
                              prov.addToCart(result);
                              setState(() {
                                _query = '';
                                _searchCtrl.clear();
                              });
                            } else {
                              // barcode tidak ditemukan di produk
                              setState(() {
                                _query = result.toString();
                                _searchCtrl.text = result.toString();
                              });
                              prov.showToast('Produk tidak ditemukan untuk barcode ini');
                            }
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.qr_code_scanner, size: 17, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Image.asset('assets/icons/ic_search.png', width: 22, fit: BoxFit.contain),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _query = v),
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.text),
                              decoration: InputDecoration(
                                hintText: 'Cari nama produk atau barcode',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Category tabs — dinamis dari Supabase
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Semua', ...dummyKategori].map((c) {
                          final isLast = c == (dummyKategori.isEmpty ? 'Semua' : dummyKategori.last);
                          return Padding(
                            padding: EdgeInsets.only(right: isLast ? 0 : 8),
                            child: CategoryChip(
                              label: c,
                              isSelected: _category == c,
                              onTap: () => setState(() => _category = c),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Product list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<AppProvider>().refreshData(),
              color: AppColors.primary,
              child: products.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Produk tidak ditemukan\nTarik ke bawah untuk refresh',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim, height: 1.6),
                        ),
                      ),
                    ],
                  )
                : crossAxis == 1
                    ? ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 12, 16, prov.hasCart ? 160 : 104),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ProductCard(
                          product: products[i],
                          onLongPress: () => _showProductActions(context, products[i]),
                        ),
                      )
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 12, 16, prov.hasCart ? 160 : 104),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxis,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: products.length,
                        itemBuilder: (_, i) => _ProductCard(
                          product: products[i],
                          onLongPress: () => _showProductActions(context, products[i]),
                        ),
                      ),
            ),
          ),
        ],
      ),
      // Cart floating bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomSheet: prov.hasCart
          ? _CartBar(
              count: prov.cartItemCount,
              total: formatRp(prov.total),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
              },
            )
          : null,
    );
  }
}

Widget _fieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
);

InputDecoration _inputDeco(String hint, {String? prefix}) => InputDecoration(
  hintText: hint,
  prefixText: prefix != null ? '$prefix ' : null,
  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
  prefixStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
  filled: true,
  fillColor: AppColors.bg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626))),
  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
);

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(label, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minLeadingWidth: 38,
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onLongPress;
  const _ProductCard({required this.product, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    final isNonAktif = product.status == 'Non-aktif';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isNonAktif ? null : () => prov.addToCart(product),
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF101828).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              InitialsAvatar(
                text: product.initials,
                size: 58,
                fontSize: 16,
                borderRadius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.nama,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNonAktif) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Non-aktif',
                              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF92400E))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.barcode_reader, size: 11, color: AppColors.textDim),
                        const SizedBox(width: 5),
                        Text(
                          product.barcode,
                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.textDim, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          formatRp(product.harga),
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Stok ${product.stok} ${product.satuan}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: product.isLowStock ? AppColors.red : AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isNonAktif)
                Consumer<AppProvider>(
                  builder: (_, prov, __) {
                    final inCart = prov.cart.containsKey(product.id);
                    return GestureDetector(
                      onTap: () => prov.addToCart(product),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: inCart ? AppColors.primaryDark : AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int count;
  final String total;
  final VoidCallback onTap;

  const _CartBar({required this.count, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 82),
      child: Material(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 19),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count item di keranjang',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      'Ketuk untuk lanjut',
                      style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  total,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
