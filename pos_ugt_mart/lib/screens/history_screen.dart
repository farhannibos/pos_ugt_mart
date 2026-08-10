import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../widgets/ugt_widgets.dart';
import 'transaction_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'Semua';
  final List<String> _filters = ['Semua', 'Lunas', 'Piutang', 'Tunai', 'Non Tunai'];

  List<Transaction> get _filtered {
    switch (_filter) {
      case 'Lunas':     return dummyHistory.where((h) => h.status == 'Lunas').toList();
      case 'Piutang':   return dummyHistory.where((h) => h.status == 'Piutang').toList();
      case 'Tunai':     return dummyHistory.where((h) => h.metode == 'Tunai').toList();
      case 'Non Tunai': return dummyHistory.where((h) => h.metode != 'Tunai').toList();
      default:          return dummyHistory;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>(); // rebuild when new transaction added
    final history = _filtered;
    final isWide = MediaQuery.of(context).size.width > 600;
    final totalLunas = history
        .where((h) => h.status == 'Lunas')
        .fold(0, (s, h) => s + h.total);

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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Penjualan',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((f) => Padding(
                          padding: EdgeInsets.only(right: f == _filters.last ? 0 : 8),
                          child: CategoryChip(
                            label: f,
                            isSelected: _filter == f,
                            onTap: () => setState(() => _filter = f),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // List
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 720.0 : double.infinity),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => context.read<AppProvider>().refreshData(),
                  child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, isWide ? 24 : 104),
              children: [
                // Summary
                UGTCard(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total (${_filter == 'Semua' ? 'semua' : _filter.toLowerCase()})', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
                          const SizedBox(height: 2),
                          Text(
                            formatRp(totalLunas),
                            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Transaksi', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
                          const SizedBox(height: 2),
                          Text('${history.length}', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...history.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HistoryCard(
                    trx: h,
                    onTap: () {
                      context.read<AppProvider>().selectedTransaction = h;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TransactionDetailScreen()),
                      );
                    },
                  ),
                )),
              ],
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Transaction trx;
  final VoidCallback onTap;

  const _HistoryCard({required this.trx, required this.onTap});

  IconData get _icon {
    if (trx.metode == 'QRIS') return Icons.qr_code_2;
    if (trx.metode.contains('EDC') || trx.metode.contains('Kartu')) return Icons.credit_card;
    if (trx.metode == 'Voucher') return Icons.confirmation_number_outlined;
    return Icons.payments_outlined;
  }

  bool get _isWarning => trx.status == 'Piutang' || trx.status == 'Pending';
  Color get _iconBg => _isWarning ? AppColors.yellowLight : AppColors.primaryLight;
  Color get _iconFg => _isWarning ? AppColors.yellowText : AppColors.primary;
  Color get _badgeBg => _isWarning ? AppColors.yellowLight : AppColors.primaryLight;
  Color get _badgeFg => _isWarning ? AppColors.yellowText : AppColors.primaryDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_icon, size: 18, color: _iconFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            trx.id,
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _badgeBg,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(trx.status, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: _badgeFg)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trx.tanggal}  ${trx.jam}',
                      style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${trx.metode} · ${trx.items} item · ${trx.customer}',
                      style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                formatRp(trx.total),
                style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
