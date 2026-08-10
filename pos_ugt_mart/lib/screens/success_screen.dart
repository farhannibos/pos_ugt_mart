import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/ugt_widgets.dart';
import '../services/receipt_service.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.06), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 1.0)), curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    final last = prov.lastTransaction;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Green top
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 34, 20, 46),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // Checkmark animation
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 28, color: AppColors.primary, weight: 700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _fade,
                      child: Column(
                        children: [
                          Text(
                            'Pembayaran Berhasil',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${last?['id'] ?? '-'} · ${last?['time'] ?? '-'}',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Body
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 500 : double.infinity),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    // Receipt card (overlaps green header)
                    Transform.translate(
                      offset: const Offset(0, -26),
                      child: UGTCard(
                        borderRadius: 20,
                        shadows: [
                          BoxShadow(
                            color: const Color(0xFF101828).withValues(alpha: 0.07),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            // Total
                            Container(
                              padding: const EdgeInsets.only(bottom: 12),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.borderLight, style: BorderStyle.solid)),
                              ),
                              child: Column(
                                children: [
                                  Text('Total Dibayar', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatRp(last?['total'] ?? 0),
                                    style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Details
                            _DetailRow('Metode', last?['method'] ?? '-'),
                            const SizedBox(height: 9),
                            _DetailRow('Uang Diterima', formatRp(last?['cash'] ?? 0)),
                            const SizedBox(height: 9),
                            _DetailRow('Kembalian', formatRp(last?['change'] ?? 0)),
                            const SizedBox(height: 9),
                            _DetailRow('Pelanggan', last?['customer'] ?? 'Umum'),
                            const SizedBox(height: 9),
                            _DetailRow('Kasir', prov.kasirName),
                            if ((last?['note'] as String? ?? '').isNotEmpty) ...[
                              const SizedBox(height: 9),
                              _DetailRow('Catatan', last!['note'] as String),
                            ],
                            // Points
                            if ((last?['points'] ?? 0) > 0) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.star_outline, size: 15, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '+${last?['points'] ?? 0} poin ditambahkan ke member',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Action buttons
                    Transform.translate(
                      offset: const Offset(0, -12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _OutlineButton(
                                  icon: Icons.print_outlined,
                                  label: 'Cetak Struk',
                                  onTap: () {
                                    final trx = prov.lastTrxObj;
                                    final meta = prov.lastTransaction;
                                    if (trx == null || meta == null) return;
                                    ReceiptService.printReceipt(trx: trx, meta: meta);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _OutlineButton(
                                  icon: Icons.share_outlined,
                                  label: 'Kirim',
                                  onTap: () {
                                    final trx = prov.lastTrxObj;
                                    final meta = prov.lastTransaction;
                                    if (trx == null || meta == null) return;
                                    ReceiptService.shareReceipt(trx: trx, meta: meta);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: Material(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(15),
                              child: InkWell(
                                onTap: () {
                                  prov.startNewTransaction();
                                  Navigator.of(context).popUntil((route) => route.isFirst);
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add, color: Colors.white, size: 16),
                                      const SizedBox(width: 9),
                                      Text(
                                        'Transaksi Baru',
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              prov.startNewTransaction();
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              child: Text(
                                'Kembali ke Beranda',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
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

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({required this.icon, required this.label, required this.onTap});

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
