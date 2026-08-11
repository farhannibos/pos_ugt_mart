import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/purchase.dart';
import '../services/db_service.dart';
import '../widgets/ugt_widgets.dart';
import 'tambah_pembelian_screen.dart';
import 'supplier_screen.dart';

class PembelianScreen extends StatefulWidget {
  const PembelianScreen({super.key});

  @override
  State<PembelianScreen> createState() => _PembelianScreenState();
}

class _PembelianScreenState extends State<PembelianScreen> {
  String _filter = 'Semua'; // Semua / Lunas / Hutang

  List<Purchase> get _filtered {
    if (_filter == 'Semua') return dummyPurchases;
    return dummyPurchases.where((p) => p.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final canAdd = prov.kasirRole == 'Owner' || prov.kasirRole == 'Admin';
    final isWide = MediaQuery.of(context).size.width > 600;

    final todayPrefix = _todayPrefix();
    final todayCount = dummyPurchases.where((p) => p.id.startsWith(todayPrefix)).length;
    final todayTotal = dummyPurchases
        .where((p) => p.id.startsWith(todayPrefix))
        .fold(0, (s, p) => s + p.total);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Header
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(color: AppColors.primary, height: MediaQuery.of(context).padding.top),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: Builder(
                  builder: (ctx) {
                    return Stack(
                      children: [
                        // Full-width image background
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/bg_pembelian_header.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                          ),
                        ),
                        // Left overlay so text stays readable
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xD0063E31), Color(0x40063E31), Colors.transparent],
                                stops: [0.0, 0.45, 0.75],
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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
                                    child: Text(
                                      'Pembelian Barang',
                                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ),
                                  if (canAdd)
                                    GestureDetector(
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const SupplierScreen()),
                                        );
                                        setState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white30),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.storefront_outlined, size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text('Supplier',
                                                style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _HeaderStat(label: 'Hari Ini', value: '$todayCount PO')),
                                  const SizedBox(width: 12),
                                  Expanded(child: _HeaderStat(label: 'Total Pembelian', value: formatRp(todayTotal))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _HeaderStat(
                                      label: 'Hutang',
                                      value: formatRp(dummyPurchases
                                        .where((p) => p.status == 'Hutang')
                                        .fold(0, (s, p) => s + p.sisaHutang)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: ['Semua', 'Lunas', 'Hutang'].map((f) {
                final active = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.bg,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: active ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(
                        f,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<AppProvider>().refreshData(),
              child: _filtered.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/icons/ic_pembelian.png', width: 80, fit: BoxFit.contain),
                              const SizedBox(height: 12),
                              Text('Belum ada data pembelian', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isWide ? 720.0 : double.infinity),
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, isWide ? 24 : 100),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _PurchaseCard(
                            purchase: _filtered[i],
                            onChanged: () => setState(() {}),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () async {
                final added = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const TambahPembelianScreen()),
                );
                if (added == true && mounted) setState(() {});
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Input Pembelian', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
            )
          : null,
    );
  }

  String _todayPrefix() {
    final now = DateTime.now();
    return 'PO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 3),
          Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onChanged;
  const _PurchaseCard({required this.purchase, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isHutang = purchase.status == 'Hutang';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Image.asset('assets/icons/ic_pembelian.png', width: 48, fit: BoxFit.contain),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.supplierNama,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${purchase.id} · ${purchase.tanggal} ${purchase.jam}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${purchase.items.length} item',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRp(purchase.total),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isHutang ? AppColors.yellowLight : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      purchase.status,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isHutang ? AppColors.yellowText : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseDetailSheet(purchase: purchase, onChanged: onChanged),
    );
  }
}

class _PurchaseDetailSheet extends StatefulWidget {
  final Purchase purchase;
  final VoidCallback onChanged;
  const _PurchaseDetailSheet({required this.purchase, required this.onChanged});

  @override
  State<_PurchaseDetailSheet> createState() => _PurchaseDetailSheetState();
}

class _PurchaseDetailSheetState extends State<_PurchaseDetailSheet> {
  final _nominalCtrl = TextEditingController();
  bool _loading = false;

  Purchase get purchase => widget.purchase;

  @override
  void dispose() {
    _nominalCtrl.dispose();
    super.dispose();
  }

  Future<void> _bayar(int nominal) async {
    if (nominal <= 0 || nominal > purchase.sisaHutang) return;
    setState(() => _loading = true);
    final prov = context.read<AppProvider>();
    final ok = await DbService.catatCicilanHutang(purchase, nominal);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      _nominalCtrl.clear();
      widget.onChanged();
      prov.showToast(purchase.status == 'Lunas'
          ? 'Hutang berhasil dilunasi'
          : 'Cicilan Rp${formatRp(nominal)} tercatat');
      setState(() {});
      if (purchase.status == 'Lunas' && mounted) Navigator.of(context).pop();
    } else {
      prov.showToast('Gagal mencatat pembayaran, cek koneksi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(purchase.id, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: purchase.status == 'Hutang' ? AppColors.yellowLight : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  purchase.status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: purchase.status == 'Hutang' ? AppColors.yellowText : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${purchase.supplierNama} · ${purchase.tanggal} ${purchase.jam}',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim)),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...purchase.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.namaProduk, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text)),
                      Text('${item.qty} × ${formatRp(item.hargaBeli)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                    ],
                  ),
                ),
                Text(formatRp(item.subtotal), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              ],
            ),
          )),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
              Text(formatRp(purchase.total), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
          if (purchase.status == 'Hutang') ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sudah dibayar', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textDim)),
                Text(formatRp(purchase.terbayar), style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textDim)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sisa Hutang', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.yellowText)),
                Text(formatRp(purchase.sisaHutang), style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.yellowText)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Bayar Sebagian', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Text('Rp', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDim)),
                  Expanded(
                    child: TextField(
                      controller: _nominalCtrl,
                      enabled: !_loading,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDim),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _bayar(int.tryParse(_nominalCtrl.text) ?? 0),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                    child: Text('Bayar Sebagian', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _bayar(purchase.sisaHutang),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Lunasi', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
