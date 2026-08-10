import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/ugt_widgets.dart';
import '../services/receipt_service.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    final trx = prov.selectedTransaction;
    if (trx == null) return const SizedBox.shrink();

    final isLunas = trx.status == 'Lunas';
    final badgeBg = isLunas ? AppColors.primaryLight : AppColors.yellowLight;
    final badgeFg = isLunas ? AppColors.primaryDark : AppColors.yellowText;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
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
                    Expanded(
                      child: Text(
                        'Detail Transaksi',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                UGTCard(
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trx.id, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                                const SizedBox(height: 3),
                                Text(
                                  '${trx.tanggal}, ${trx.jam} · Kasir ${prov.kasirName}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              trx.status,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: badgeFg),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: DashedDivider(),
                      ),
                      ...trx.cartItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              '${item.qty}× ${item.nama}',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              formatRp(item.subtotal),
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: DashedDivider(),
                      ),
                      _DetailRow('Metode', trx.metode),
                      const SizedBox(height: 8),
                      _DetailRow('Pelanggan', trx.customer),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Total', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                          const Spacer(),
                          Text(
                            formatRp(trx.total),
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ActionButton(
                  icon: Icons.print_outlined,
                  label: 'Cetak Ulang',
                  onTap: () {
                    final meta = <String, dynamic>{
                      'storeName': prov.storeName,
                      'alamat': prov.alamatToko,
                      'terminal': prov.terminalName,
                      'kasir': prov.kasirName,
                      'subtotal': trx.total,
                      'discount': 0,
                      'taxRate': 0.0,
                      'taxValue': 0,
                      'roundUp': 0,
                      'method': trx.metode,
                      'cash': trx.total,
                      'change': 0,
                      'customer': trx.customer,
                      'points': 0,
                    };
                    ReceiptService.printReceipt(trx: trx, meta: meta);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.text),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}
