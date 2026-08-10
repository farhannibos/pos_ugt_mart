import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/transaction.dart';
import '../widgets/ugt_widgets.dart';
import '../services/db_service.dart';

class KasScreen extends StatefulWidget {
  final String initialType;
  const KasScreen({super.key, this.initialType = 'masuk'});

  @override
  State<KasScreen> createState() => _KasScreenState();
}

class _KasScreenState extends State<KasScreen> {
  late String _kasType;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  final _quickAmounts = [50000, 100000, 500000, 1000000];

  @override
  void initState() {
    super.initState();
    _kasType = widget.initialType;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.read<AppProvider>();
    final isMasuk = _kasType == 'masuk';
    final isWide = MediaQuery.of(context).size.width > 600;

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
                    Text(
                      'Kas Masuk & Kas Keluar',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 640.0 : double.infinity),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => context.read<AppProvider>().refreshData(),
                  child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                // Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _TabBtn(label: 'Kas Masuk', selected: isMasuk, onTap: () => setState(() => _kasType = 'masuk'))),
                      Expanded(child: _TabBtn(label: 'Kas Keluar', selected: !isMasuk, isKeluar: true, onTap: () => setState(() => _kasType = 'keluar'))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Input card
                UGTCard(
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nominal',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 9),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Text(
                              'Rp',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDim),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _amountCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDim),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickAmounts.map((v) => GestureDetector(
                          onTap: () => setState(() => _amountCtrl.text = v.toString()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: AppColors.primaryMid),
                            ),
                            child: Text(
                              formatRp(v),
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Keterangan',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 9),
                      TextField(
                        controller: _noteCtrl,
                        style: GoogleFonts.inter(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'mis. modal awal shift / setor ke bank',
                          hintStyle: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textDim),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                          filled: true,
                          fillColor: AppColors.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Material(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(15),
                          child: InkWell(
                            onTap: () {
                              final amount = int.tryParse(_amountCtrl.text) ?? 0;
                              if (amount == 0) {
                                prov.showToast('Nominal belum diisi');
                                return;
                              }
                              final now = DateTime.now();
                              final jam =
                                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                              final ket = _noteCtrl.text.trim().isEmpty
                                  ? (_kasType == 'masuk' ? 'Kas masuk' : 'Kas keluar')
                                  : _noteCtrl.text.trim();
                              setState(() {
                                dummyKasLog.insert(0, KasLog(ket: ket, jam: jam, nominal: amount, tipe: _kasType));
                              });
                              DbService.saveKas(ket, _kasType, amount, prov.kasirName);
                              prov.showToast('Kas $_kasType ${formatRp(amount)} tersimpan');
                              _amountCtrl.clear();
                              _noteCtrl.clear();
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
                                  const Icon(Icons.save_outlined, color: Colors.white, size: 16),
                                  const SizedBox(width: 9),
                                  Text(
                                    'Simpan',
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Mutasi Kas Hari Ini',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                UGTCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: dummyKasLog.map((k) => _KasLogItem(log: k, isLast: k == dummyKasLog.last)).toList(),
                  ),
                ),
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

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isKeluar;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.selected, this.isKeluar = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFF101828).withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? (isKeluar ? AppColors.red : AppColors.primary)
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _KasLogItem extends StatelessWidget {
  final KasLog log;
  final bool isLast;

  const _KasLogItem({required this.log, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isMasuk = log.tipe == 'masuk';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isMasuk ? AppColors.primaryLight : AppColors.redLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isMasuk ? Icons.arrow_upward : Icons.arrow_downward,
              size: 15,
              color: isMasuk ? AppColors.primary : AppColors.red,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.ket, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text(log.jam, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
              ],
            ),
          ),
          Text(
            '${isMasuk ? '+' : '-'} ${formatRp(log.nominal)}',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isMasuk ? AppColors.primary : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}
