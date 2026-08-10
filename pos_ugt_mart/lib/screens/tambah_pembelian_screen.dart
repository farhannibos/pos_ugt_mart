import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/purchase.dart';
import '../models/product.dart';
import '../services/db_service.dart';
import '../widgets/ugt_widgets.dart';
import 'supplier_screen.dart';

class TambahPembelianScreen extends StatefulWidget {
  const TambahPembelianScreen({super.key});

  @override
  State<TambahPembelianScreen> createState() => _TambahPembelianScreenState();
}

class _TambahPembelianScreenState extends State<TambahPembelianScreen> {
  Supplier? _selectedSupplier;
  final _supplierCtrl = TextEditingController();
  final List<PurchaseItem> _items = [];
  String _status = 'Lunas';
  bool _saving = false;

  int get _total => _items.fold(0, (s, i) => s + i.subtotal);

  @override
  void dispose() {
    _supplierCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProductPickerSheet(),
    );
    if (product == null) return;

    // Check if already added
    final existing = _items.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      setState(() => _items[existing].qty++);
      return;
    }

    setState(() {
      _items.add(PurchaseItem(
        productId: product.id,
        namaProduk: product.nama,
        qty: 1,
        hargaBeli: (product.harga * 0.8).round(), // estimate 80% of jual
      ));
    });
  }

  Future<void> _save() async {
    final supplierNama = _selectedSupplier?.nama ?? _supplierCtrl.text.trim();
    if (supplierNama.isEmpty) {
      _showError('Pilih atau masukkan nama supplier');
      return;
    }
    if (_items.isEmpty) {
      _showError('Tambahkan minimal 1 item');
      return;
    }
    for (final item in _items) {
      if (item.hargaBeli <= 0) {
        _showError('Harga beli ${item.namaProduk} tidak valid');
        return;
      }
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final todayPrefix = 'PO-$dateStr';
    final count = dummyPurchases.where((p) => p.id.startsWith(todayPrefix)).length;
    final id = '$todayPrefix-${(count + 1).toString().padLeft(3, '0')}';

    final tanggalDisplay = '${now.day.toString().padLeft(2, '0')} ${_bulan(now.month)} ${now.year}';
    final tanggalIso = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final jam = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final purchase = Purchase(
      id: id,
      supplierNama: supplierNama,
      tanggal: tanggalDisplay,
      tanggalIso: tanggalIso,
      jam: jam,
      total: _total,
      status: _status,
      items: List.from(_items),
    );

    dummyPurchases.insert(0, purchase);

    // Update local stock
    for (final item in _items) {
      final idx = dummyProducts.indexWhere((p) => p.id == item.productId);
      if (idx >= 0) dummyProducts[idx].stok += item.qty;
    }

    final prov = context.read<AppProvider>();
    DbService.savePurchase(purchase, _selectedSupplier?.id, prov.kasirName);

    if (mounted) {
      setState(() => _saving = false);
      prov.showToast('Pembelian $id berhasil disimpan');
      Navigator.of(context).pop(true);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating),
    );
  }

  String _bulan(int m) {
    const b = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return b[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Input Pembelian', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Simpan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Supplier
          _SectionLabel('Supplier'),
          const SizedBox(height: 8),
          _SupplierField(
            selected: _selectedSupplier,
            ctrl: _supplierCtrl,
            onSelect: (s) => setState(() {
              _selectedSupplier = s;
              _supplierCtrl.text = s?.nama ?? '';
            }),
          ),
          const SizedBox(height: 20),

          // Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel('Item Pembelian'),
              TextButton.icon(
                onPressed: _pickProduct,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: Text('Tambah', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.add_shopping_cart_outlined, size: 36, color: AppColors.placeholder),
                  const SizedBox(height: 8),
                  Text('Belum ada item', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim)),
                ],
              ),
            )
          else
            ..._items.asMap().entries.map((e) => _ItemRow(
              item: e.value,
              onRemove: () => setState(() => _items.removeAt(e.key)),
              onChanged: () => setState(() {}),
            )),

          const SizedBox(height: 20),

          // Status payment
          _SectionLabel('Status Pembayaran'),
          const SizedBox(height: 8),
          Row(
            children: ['Lunas', 'Hutang'].map((s) {
              final active = _status == s;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: s == 'Lunas' ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: active ? (s == 'Lunas' ? AppColors.primary : AppColors.yellow) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active ? Colors.transparent : AppColors.border,
                        ),
                      ),
                      child: Text(
                        s,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),

      // Total bar
      bottomNavigationBar: _items.isEmpty
          ? null
          : Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Pembelian', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                      Text(formatRp(_total), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Simpan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
  );
}

class _SupplierField extends StatelessWidget {
  final Supplier? selected;
  final TextEditingController ctrl;
  final void Function(Supplier?) onSelect;

  const _SupplierField({required this.selected, required this.ctrl, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<Supplier?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SupplierPickerSheet(current: selected),
        );
        if (result != null) onSelect(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected != null ? AppColors.primary : AppColors.border, width: selected != null ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, size: 18, color: selected != null ? AppColors.primary : AppColors.placeholder),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected?.nama ?? 'Pilih supplier...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: selected != null ? AppColors.text : AppColors.placeholder,
                ),
              ),
            ),
            if (selected != null)
              GestureDetector(
                onTap: () => onSelect(null),
                child: const Icon(Icons.close, size: 16, color: AppColors.textDim),
              )
            else
              const Icon(Icons.chevron_right, size: 18, color: AppColors.placeholder),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatefulWidget {
  final PurchaseItem item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRow({required this.item, required this.onRemove, required this.onChanged});

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _hargaCtrl;
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _hargaCtrl = TextEditingController(text: widget.item.hargaBeli.toString());
    _qtyCtrl = TextEditingController(text: widget.item.qty.toString());
  }

  @override
  void dispose() {
    _hargaCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.namaProduk,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ),
              GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _NumField(
                  label: 'Harga Beli',
                  ctrl: _hargaCtrl,
                  prefix: 'Rp ',
                  onChanged: (v) {
                    widget.item.hargaBeli = int.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: _NumField(
                  label: 'Qty',
                  ctrl: _qtyCtrl,
                  onChanged: (v) {
                    widget.item.qty = int.tryParse(v)?.clamp(1, 9999) ?? 1;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Subtotal: ${formatRp(widget.item.subtotal)}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String prefix;
  final ValueChanged<String> onChanged;

  const _NumField({required this.label, required this.ctrl, this.prefix = '', required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            fillColor: AppColors.bg,
            filled: true,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Product Picker Bottom Sheet ──────────────────────────────────────────────
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  List<Product> get _filtered {
    if (_query.isEmpty) return dummyProducts;
    return dummyProducts.where((p) => p.nama.toLowerCase().contains(_query.toLowerCase())).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.placeholder),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = _filtered[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  title: Text(p.nama, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(p.kategori, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatRp(p.harga), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      Text('Stok: ${p.stok}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                    ],
                  ),
                  onTap: () => Navigator.of(ctx).pop(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supplier Picker Bottom Sheet ─────────────────────────────────────────────
class _SupplierPickerSheet extends StatefulWidget {
  final Supplier? current;
  const _SupplierPickerSheet({this.current});

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  String _query = '';

  List<Supplier> get _list {
    final aktif = dummySuppliers.where((s) => s.status == 'Aktif').toList();
    if (_query.isEmpty) return aktif;
    final q = _query.toLowerCase();
    return aktif.where((s) =>
        s.nama.toLowerCase().contains(q) ||
        s.kontak.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pilih Supplier',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupplierScreen()),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: Text('Tambah',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search
          TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari supplier...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.placeholder),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.placeholder),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  dummySuppliers.isEmpty
                      ? 'Belum ada supplier. Tambahkan dulu.'
                      : 'Tidak ditemukan',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final s = list[i];
                  final isSelected = widget.current?.id == s.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text(
                          s.nama[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ),
                    ),
                    title: Text(s.nama,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: s.kontak.isNotEmpty
                        ? Text(s.kontak,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.textDim))
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 18)
                        : null,
                    onTap: () => Navigator.of(context).pop(s),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
