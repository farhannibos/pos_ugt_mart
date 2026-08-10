import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';
import '../widgets/ugt_widgets.dart';
import 'product_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    final lowStockProducts = dummyProducts.where((p) => p.isLowStock).take(3).toList();

    // Real stat calculations
    final penjualanHariIni = prov.todayTotalPenjualan;
    final kemarinTotal = prov.kemarinTotalPenjualan;
    final trxCount = prov.todayTrxCount;
    final rataRata = trxCount > 0 ? penjualanHariIni ~/ trxCount : 0;
    final itemsTerjual = prov.todayItemsCount;
    final skuTerjual = prov.todaySkuCount;

    final modalAwal    = prov.activeShift?.modalAwal ?? 0;
    final tunaiJual    = prov.todayTunaiTotal;
    final kasMasuk     = prov.shiftKasMasuk;
    final kasKeluar    = prov.shiftKasKeluar;
    final kasTunai     = prov.shiftSaldoSeharusnya;

    String kasTunaiTrend;
    if (prov.activeShift == null) {
      kasTunaiTrend = 'shift belum dibuka';
    } else {
      final parts = <String>[];
      parts.add('modal ${formatRp(modalAwal)}');
      if (tunaiJual > 0) parts.add('+jual ${formatRp(tunaiJual)}');
      if (kasMasuk > 0)  parts.add('+masuk ${formatRp(kasMasuk)}');
      if (kasKeluar > 0) parts.add('-keluar ${formatRp(kasKeluar)}');
      kasTunaiTrend = parts.join(' ');
    }

    String trendPenjualan;
    bool? trendPositive;
    if (kemarinTotal == 0) {
      trendPenjualan = 'belum ada data kemarin';
      trendPositive = null;
    } else {
      final pct = ((penjualanHariIni - kemarinTotal) / kemarinTotal * 100);
      final sign = pct >= 0 ? '+' : '';
      trendPenjualan = '$sign${pct.toStringAsFixed(1)}% vs kemarin';
      trendPositive = pct >= 0;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => context.read<AppProvider>().refreshData(),
        child: CustomScrollView(
        slivers: [
          // Green header
          SliverToBoxAdapter(child: _DashHeader(kasir: prov.kasirName)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              isWide ? 24 : 104,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stat grid
                isWide
                    ? Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Penjualan Hari Ini', value: formatRp(penjualanHariIni), trend: trendPenjualan, trendPositive: trendPositive)),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(label: 'Total Transaksi', value: '$trxCount', trend: rataRata > 0 ? 'rata-rata ${formatRp(rataRata)}' : 'belum ada transaksi', trendPositive: null)),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(label: 'Kas Tunai', value: formatRp(kasTunai), trend: kasTunaiTrend, trendPositive: null)),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(label: 'Produk Terjual', value: '$itemsTerjual pcs', trend: '$skuTerjual SKU berbeda', trendPositive: null)),
                        ],
                      )
                    : GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.55,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatCard(label: 'Penjualan Hari Ini', value: formatRp(penjualanHariIni), trend: trendPenjualan, trendPositive: trendPositive),
                          _StatCard(label: 'Total Transaksi', value: '$trxCount', trend: rataRata > 0 ? 'rata-rata ${formatRp(rataRata)}' : 'belum ada transaksi', trendPositive: null),
                          _StatCard(label: 'Kas Tunai', value: formatRp(kasTunai), trend: kasTunaiTrend, trendPositive: null),
                          _StatCard(label: 'Produk Terjual', value: '$itemsTerjual pcs', trend: '$skuTerjual SKU berbeda', trendPositive: null),
                        ],
                      ),
                const SizedBox(height: 14),
                // Transaksi Baru CTA
                _NewTransactionButton(onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductScreen()))),
                const SizedBox(height: 16),
                // Chart
                _SalesChart(),
                const SizedBox(height: 18),
                // Quick menu
                Text(
                  'Menu Cepat',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                _QuickMenu(),
                const SizedBox(height: 18),
                // Low stock
                Text(
                  'Stok Menipis',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                _LowStockList(products: lowStockProducts),
              ]),
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
  const _DashHeader({required this.kasir});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
          child: Row(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift Pagi · 08:00–16:00',
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
                    child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final bool? trendPositive;

  const _StatCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.trendPositive,
  });

  @override
  Widget build(BuildContext context) {
    return UGTCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 15, color: AppColors.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 3),
          Text(
            trend,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: trendPositive == true ? AppColors.primary : AppColors.textDim,
            ),
          ),
        ],
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18),
              ),
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
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isOwnerOrAdmin = prov.kasirRole == 'Owner' || prov.kasirRole == 'Admin';
    final items = [
      _QuickItem(
        icon: Icons.inventory_2_outlined,
        label: 'Produk',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductScreen()),
        ),
      ),
      _QuickItem(icon: Icons.arrow_upward, label: 'Kas Masuk', onTap: () => _go(context, '/kas-masuk')),
      _QuickItem(icon: Icons.arrow_downward, label: 'Kas Keluar', onTap: () => _go(context, '/kas-keluar')),
      if (isOwnerOrAdmin)
        _QuickItem(icon: Icons.local_shipping_outlined, label: 'Pembelian', onTap: () => _go(context, '/pembelian')),
      _QuickItem(icon: Icons.person_outline, label: 'Member', onTap: () => _go(context, '/member')),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) => SizedBox(
        width: 88,
        child: _QuickMenuItem(item: item),
      )).toList(),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickItem({required this.icon, required this.label, required this.onTap});
}

class _QuickMenuItem extends StatelessWidget {
  final _QuickItem item;
  const _QuickMenuItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
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
