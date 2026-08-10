import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../widgets/ugt_widgets.dart';

class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    final m = prov.selectedMember;
    if (m == null) return const SizedBox.shrink();
    final isWide = MediaQuery.of(context).size.width > 600;

    final history = dummyHistory.where((h) => h.customer == m.nama).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // AppBar
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 24, color: AppColors.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Detail Member',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 640.0 : double.infinity),
                child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Profile card
                UGTCard(
                  borderRadius: 20,
                  child: Row(
                    children: [
                      InitialsAvatar(
                        text: m.initials,
                        size: 58,
                        fontSize: 18,
                        borderRadius: 18,
                        bgColor: AppColors.primaryLight,
                        textColor: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.nama, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                            const SizedBox(height: 3),
                            Text(m.hp, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textDim)),
                            const SizedBox(height: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'Member ${m.tier}',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Poin', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8))),
                            const SizedBox(height: 3),
                            Text(
                              m.poin.toString(),
                              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: UGTCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Belanja', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
                            const SizedBox(height: 3),
                            Text(
                              formatRp(m.spend),
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Riwayat Transaksi',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                if (history.isEmpty)
                  UGTCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Belum ada riwayat transaksi',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim),
                        ),
                      ),
                    ),
                  )
                else
                  UGTCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: history.map((h) => _HistoryItem(trx: h, isLast: h == history.last)).toList(),
                    ),
                  ),
                const SizedBox(height: 14),
                // Use member button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: () {
                        prov.useMemberForTransaction(m);
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.26),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Pakai di Transaksi Ini',
                          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
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
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Transaction trx;
  final bool isLast;

  const _HistoryItem({required this.trx, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_outlined, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trx.id, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text(
                  '${trx.tanggal}, ${trx.jam} · ${trx.metode}',
                  style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          Text(
            formatRp(trx.total),
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
