import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/purchase.dart';
import '../services/db_service.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  String _query = '';
  bool _loading = false;

  List<Supplier> get _filtered {
    if (_query.isEmpty) return dummySuppliers;
    final q = _query.toLowerCase();
    return dummySuppliers.where((s) =>
      s.nama.toLowerCase().contains(q) ||
      s.kontak.toLowerCase().contains(q)).toList();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await DbService.loadSuppliers();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openSheet({Supplier? supplier}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierFormSheet(supplier: supplier),
    );
    if (result == true) await _reload();
  }

  Future<void> _delete(Supplier s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Supplier',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text('Hapus "${s.nama}"? Pastikan tidak ada hutang aktif.',
            style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await DbService.deleteSupplier(s.id);
    if (ok) {
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Supplier "${s.nama}" dihapus'), behavior: SnackBarBehavior.floating),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal hapus. Mungkin ada data pembelian terkait.'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = _filtered;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Kelola Supplier',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                        GestureDetector(
                          onTap: () => _openSheet(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('Tambah',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Cari supplier...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Info bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${suppliers.length} supplier',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim),
                ),
                Text(
                  '${dummySuppliers.where((s) => s.status == 'Aktif').length} aktif',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : suppliers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.storefront_outlined, size: 48, color: AppColors.placeholder),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty ? 'Belum ada supplier' : 'Tidak ditemukan',
                              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
                            ),
                            if (_query.isEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _openSheet(),
                                child: Text('Tambah Supplier',
                                    style: GoogleFonts.inter(
                                        color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: suppliers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _SupplierCard(
                          supplier: suppliers[i],
                          onEdit: () => _openSheet(supplier: suppliers[i]),
                          onDelete: () => _delete(suppliers[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAktif = supplier.status == 'Aktif';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isAktif ? AppColors.primaryLight : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              supplier.nama.isNotEmpty ? supplier.nama[0].toUpperCase() : 'S',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isAktif ? AppColors.primary : AppColors.textDim),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(supplier.nama,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isAktif ? AppColors.primaryLight : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                supplier.status,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isAktif ? AppColors.primary : AppColors.textDim),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (supplier.kontak.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 12, color: AppColors.textDim),
                  const SizedBox(width: 4),
                  Text(supplier.kontak,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim)),
                ],
              ),
            if (supplier.alamat.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textDim),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(supplier.alamat,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
              onPressed: onDelete,
              tooltip: 'Hapus',
            ),
          ],
        ),
        isThreeLine: supplier.alamat.isNotEmpty,
      ),
    );
  }
}

// ── Form Sheet ────────────────────────────────────────────────────────────────

class _SupplierFormSheet extends StatefulWidget {
  final Supplier? supplier;
  const _SupplierFormSheet({this.supplier});

  @override
  State<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<_SupplierFormSheet> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _kontakCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _alamatCtrl;
  late String _status;
  bool _saving = false;

  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _namaCtrl   = TextEditingController(text: s?.nama ?? '');
    _kontakCtrl = TextEditingController(text: s?.kontak ?? '');
    _emailCtrl  = TextEditingController(text: s?.email ?? '');
    _alamatCtrl = TextEditingController(text: s?.alamat ?? '');
    _status     = s?.status ?? 'Aktif';
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _kontakCtrl.dispose();
    _emailCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama supplier wajib diisi'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);

    bool ok;
    if (_isEdit) {
      ok = await DbService.updateSupplier(
        id:     widget.supplier!.id,
        nama:   nama,
        kontak: _kontakCtrl.text.trim(),
        email:  _emailCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        status: _status,
      );
    } else {
      final id = await DbService.saveSupplier(
        nama:   nama,
        kontak: _kontakCtrl.text.trim(),
        email:  _emailCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        status: _status,
      );
      ok = id != null;
    }

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan supplier'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEdit ? 'Edit Supplier' : 'Tambah Supplier',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text),
                  ),
                  // Status toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['Aktif', 'Non-aktif'].map((s) {
                      final active = _status == s;
                      return GestureDetector(
                        onTap: () => setState(() => _status = s),
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? (s == 'Aktif' ? AppColors.primaryLight : const Color(0xFFFFE4E6))
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active
                                  ? (s == 'Aktif' ? AppColors.primary : AppColors.red)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            s,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? (s == 'Aktif' ? AppColors.primary : AppColors.red)
                                  : AppColors.textDim,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _Field(label: 'Nama Supplier *', ctrl: _namaCtrl,
                  hint: 'Nama perusahaan / perorangan',
                  textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              _Field(label: 'No. Kontak', ctrl: _kontakCtrl,
                  hint: '08xxxxxxxxxx',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _Field(label: 'Email', ctrl: _emailCtrl,
                  hint: 'email@contoh.com',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _Field(label: 'Alamat', ctrl: _alamatCtrl,
                  hint: 'Alamat lengkap supplier',
                  maxLines: 2),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isEdit ? 'Simpan Perubahan' : 'Tambah Supplier',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.placeholder),
              filled: true,
              fillColor: AppColors.bg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ],
      );
}
