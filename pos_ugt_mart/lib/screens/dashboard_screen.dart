import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../widgets/ugt_widgets.dart';
import 'product_screen.dart';
import 'history_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    final lowStockProducts = dummyProducts.where((p) => p.isLowStock).take(3).toList();

    // Real stat calculations
    final trxCount   = prov.todayTrxCount;
    final omzet      = prov.todayTotalPenjualan;
    final rataRata   = trxCount > 0 ? omzet ~/ trxCount : 0;
    final piutangVal = prov.totalPiutangAktif;
    final piutangN   = prov.jumlahPiutangAktif;

    String shiftLabel;
    if (prov.activeShift == null) {
      shiftLabel = 'Belum ada shift aktif';
    } else {
      final buka = prov.activeShift!.jamBuka;
      final jam = '${buka.hour.toString().padLeft(2, '0')}:${buka.minute.toString().padLeft(2, '0')}';
      shiftLabel = 'Shift Aktif sejak $jam';
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => context.read<AppProvider>().refreshData(),
        child: CustomScrollView(
        slivers: [
          // Green header
          SliverToBoxAdapter(child: _DashHeader(kasir: prov.kasirName, shiftLabel: shiftLabel)),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, isWide ? 24 : 104),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 3 stat cards responsive ──
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _StatCard(
                              icon: Icons.trending_up_rounded,
                              iconColor: AppColors.primary,
                              label: 'Omzet Hari Ini',
                              value: formatRp(omzet),
                              sub: trxCount > 0 ? 'rata-rata ${formatRp(rataRata)}' : 'belum ada transaksi',
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(
                              icon: Icons.receipt_long_outlined,
                              iconColor: AppColors.primary,
                              label: 'Transaksi',
                              value: '$trxCount',
                              sub: trxCount > 0 ? '${prov.todayItemsCount} item terjual' : 'belum ada transaksi',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(
                              icon: Icons.pending_outlined,
                              iconColor: piutangN > 0 ? AppColors.yellow : AppColors.primary,
                              label: 'Piutang Aktif',
                              value: formatRp(piutangVal),
                              sub: piutangN > 0 ? '$piutangN transaksi belum lunas' : 'tidak ada piutang',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                            )),
                          ],
                        )
                      else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _StatCard(
                              icon: Icons.pending_outlined,
                              iconColor: piutangN > 0 ? AppColors.yellow : AppColors.primary,
                              label: 'Piutang Aktif',
                              value: formatRp(piutangVal),
                              sub: piutangN > 0 ? '$piutangN belum lunas' : 'tidak ada piutang',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(
                              icon: Icons.receipt_long_outlined,
                              iconColor: AppColors.primary,
                              label: 'Transaksi',
                              value: '$trxCount',
                              sub: trxCount > 0 ? '${prov.todayItemsCount} item terjual' : 'belum ada transaksi',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _StatCard(
                          icon: Icons.trending_up_rounded,
                          iconColor: AppColors.primary,
                          label: 'Omzet Hari Ini',
                          value: formatRp(omzet),
                          sub: trxCount > 0 ? 'rata-rata ${formatRp(rataRata)}' : 'belum ada transaksi',
                          isWide: true,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _NewTransactionButton(onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProductScreen()))),
                      const SizedBox(height: 16),
                      _SalesChart(),
                      const SizedBox(height: 18),
                      Text(
                        'Menu Cepat',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      const _QuickMenu(),
                      const SizedBox(height: 18),
                      Text(
                        'Stok Menipis',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      _LowStockList(products: lowStockProducts),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }


}

class _DashHeader extends StatelessWidget {
  final String kasir;
  final String shiftLabel;
  const _DashHeader({required this.kasir, required this.shiftLabel});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(color: AppColors.primary, height: MediaQuery.of(context).padding.top),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
          child: SizedBox(
            height: isWide ? 150 : 118,
            child: Stack(
              children: [
                // Full-width image background
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/bg_dashboard_header.png',
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
                // Content row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          kasir.split(' ').map((w) => w[0]).take(2).join().toUpperCase(),
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shiftLabel,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.78)),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              kasir,
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.read<AppProvider>().showToast('Belum ada notifikasi baru'),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset('assets/icons/ic_notif.png', width: 18, fit: BoxFit.contain),
                            ),
                            Positioned(
                              top: 8,
                              right: 9,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDE047),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;
  final bool isWide;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
    this.isWide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: UGTCard(
        child: isWide
            ? Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(value,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(sub, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 14, color: AppColors.textDim),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 14, color: iconColor),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(label,
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (onTap != null)
                        const Icon(Icons.chevron_right, size: 13, color: AppColors.textDim),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(value,
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 3),
                  Text(sub, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textDim)),
                ],
              ),
      ),
    );
  }
}

class _NewTransactionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewTransactionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.26),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Image.asset('assets/icons/ic_transaksi_baru.png', width: 40, fit: BoxFit.contain),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaksi Baru',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      'Scan barcode atau pilih produk',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesChart extends StatefulWidget {
  @override
  State<_SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<_SalesChart> {
  bool _show30 = false;

  @override
  Widget build(BuildContext context) {
    final prov        = context.watch<AppProvider>();
    final isPremium   = prov.isPremium;
    final use30       = _show30 && isPremium;
    final data        = use30 ? prov.chartDataLast30Days() : prov.chartDataLast7Days();
    final labels      = use30 ? prov.chartLabels30Days()   : prov.chartLabels7Days();
    final maxVal      = data.fold(0, (m, v) => v > m ? v : m);

    return UGTCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Grafik Penjualan',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              const Spacer(),
              if (isPremium) ...[
                _ChartFilterChip(label: '7 Hari', active: !_show30, onTap: () => setState(() => _show30 = false)),
                const SizedBox(width: 6),
                _ChartFilterChip(label: '30 Hari', active: _show30, onTap: () => setState(() => _show30 = true)),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(100)),
                  child: Text('7 hari', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
            ],
          ),
          if (isPremium && maxVal > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Tertinggi: ${formatRp(maxVal)}',
              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 104,
            child: CustomPaint(
              painter: GridLinesPainter(),
              child: CustomPaint(
                painter: SalesChartPainter(data: data),
                size: const Size(double.infinity, 104),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((d) => Text(
              d,
              style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.textDim),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChartFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ChartFilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _QuickMenu extends StatelessWidget {
  const _QuickMenu();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isOwnerOrAdmin = prov.kasirRole == 'Owner' || prov.kasirRole == 'Admin';
    final items = [
      _QuickItem(
        asset: 'assets/icons/ic_produk.png',
        label: 'Produk',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductScreen()),
        ),
      ),
      _QuickItem(asset: 'assets/icons/ic_kas_masuk.png', label: 'Kas Masuk', onTap: () => _go(context, '/kas-masuk')),
      _QuickItem(asset: 'assets/icons/ic_kas_keluar.png', label: 'Kas Keluar', onTap: () => _go(context, '/kas-keluar')),
      if (isOwnerOrAdmin)
        _QuickItem(asset: 'assets/icons/ic_pembelian.png', label: 'Pembelian', onTap: () => _go(context, '/pembelian')),
      _QuickItem(asset: 'assets/icons/ic_member.png', label: 'Member', onTap: () => _go(context, '/member')),
    ];
    final isWide = MediaQuery.of(context).size.width > 600;
    if (isWide) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) => SizedBox(
          width: 90,
          child: _QuickMenuItem(item: item),
        )).toList(),
      );
    }
    // Mobile: semua item dalam 1 baris rata, ukuran compact
    return Row(
      children: items.asMap().entries.map((e) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: e.key == 0 ? 0 : 6),
          child: _QuickMenuItem(item: e.value, compact: true),
        ),
      )).toList(),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }
}

class _QuickItem {
  final String asset;
  final String label;
  final VoidCallback onTap;
  const _QuickItem({required this.asset, required this.label, required this.onTap});
}

class _QuickMenuItem extends StatelessWidget {
  final _QuickItem item;
  final bool compact;
  const _QuickMenuItem({required this.item, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final iconSize  = compact ? 44.0 : 64.0;
    final fontSize  = compact ? 9.5  : 10.0;
    final padV      = compact ? 8.0  : 10.0;
    final padH      = compact ? 4.0  : 6.0;
    final radius    = compact ? 13.0 : 16.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF101828).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(item.asset, width: iconSize, fit: BoxFit.contain),
              const SizedBox(height: 5),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockList extends StatelessWidget {
  final List<Product> products;
  const _LowStockList({required this.products});

  @override
  Widget build(BuildContext context) {
    return UGTCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: products.map((p) => _LowStockItem(product: p, isLast: p == products.last)).toList(),
      ),
    );
  }
}

class _LowStockItem extends StatelessWidget {
  final Product product;
  final bool isLast;
  const _LowStockItem({required this.product, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          InitialsAvatar(text: product.initials, size: 34, fontSize: 12, borderRadius: 10),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nama,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  product.kategori,
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${product.stok} ${product.satuan}',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}
