import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/ugt_widgets.dart';

class ShiftScreen extends StatelessWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final shift = prov.activeShift;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _Header(),
          Expanded(
            child: shift == null
                ? _NoShiftView(onBuka: () => _showBukaDialog(context, prov))
                : _ActiveShiftView(onTutup: () => _showTutupSheet(context, prov)),
          ),
        ],
      ),
    );
  }

  void _showBukaDialog(BuildContext context, AppProvider prov) {
    showBukaShiftDialog(context, prov);
  }

  void _showTutupSheet(BuildContext context, AppProvider prov) {
    showTutupShiftSheet(context, prov);
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
                'Shift Kasir',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoShiftView extends StatelessWidget {
  final VoidCallback onBuka;
  const _NoShiftView({required this.onBuka});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.access_time_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Shift Aktif',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Buka shift untuk mulai mencatat transaksi dan kas hari ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onBuka,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text('Buka Shift', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveShiftView extends StatelessWidget {
  final VoidCallback onTutup;
  const _ActiveShiftView({required this.onTutup});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final shift = prov.activeShift!;

    final modalAwal    = shift.modalAwal;
    final kasMasuk     = prov.shiftKasMasuk;
    final kasKeluar    = prov.shiftKasKeluar;
    final saldoHitung  = prov.shiftSaldoSeharusnya;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<AppProvider>().refreshData(),
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Status card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.access_time, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shift Sedang Berjalan',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('Mulai ${shift.jamBukaStr} · Kasir: ${shift.kasirNama}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('AKTIF',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ringkasan kas
        Text('Ringkasan Kas', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        UGTCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              _KasRow(label: 'Modal Awal', value: modalAwal, showBorder: true),
              // "Kas Masuk" sudah mencakup penjualan tunai shift ini (dicatat
              // otomatis oleh trigger DB saat transaksi Tunai/Lunas tersimpan)
              // — TIDAK ditampilkan terpisah lagi supaya tidak terlihat
              // dobel-hitung terhadap "Total Seharusnya" di bawah.
              _KasRow(label: 'Kas Masuk', value: kasMasuk, showBorder: true, isPositive: true),
              _KasRow(label: 'Kas Keluar', value: kasKeluar, showBorder: true, isPositive: false),
              const SizedBox(height: 4),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 4),
              _KasRow(label: 'Total Seharusnya', value: saldoHitung, showBorder: false, isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Tombol tutup shift
        SizedBox(
          width: double.infinity,
          height: 50,
          child: Material(
            color: AppColors.redBg,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: onTutup,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.redBorder, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stop_circle_outlined, size: 18, color: AppColors.red),
                    const SizedBox(width: 9),
                    Text('Tutup Shift',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.red)),
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

class _KasRow extends StatelessWidget {
  final String label;
  final int value;
  final bool showBorder;
  final bool? isPositive;
  final bool isBold;

  const _KasRow({
    required this.label,
    required this.value,
    required this.showBorder,
    this.isPositive,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valColor = AppColors.text;
    if (isPositive == true) valColor = AppColors.primary;
    if (isPositive == false) valColor = AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: showBorder
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderLight)))
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                    color: isBold ? AppColors.text : AppColors.textSecondary)),
          ),
          Text(
            '${isPositive == true ? '+' : isPositive == false ? '-' : ''}${formatRp(value)}',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: isBold ? AppColors.text : valColor),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog Buka Shift ───────────────────────────────────────────────────────

void showBukaShiftDialog(BuildContext context, AppProvider prov) {
  final ctrl = TextEditingController();
  bool loading = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        title: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
              child: Center(child: Image.asset('assets/icons/ic_shift.png', width: 28, fit: BoxFit.contain)),
            ),
            const SizedBox(height: 12),
            Text('Buka Shift', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 4),
            Text('Masukkan modal awal di laci kasir', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim), textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modal Awal', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDim),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: loading
                ? null
                : () async {
                    setState(() => loading = true);
                    final ok = await prov.bukaShift(0);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (ok) {
                      prov.showToast('Shift dibuka · Tanpa modal awal');
                    } else {
                      prov.showToast('Gagal membuka shift, cek koneksi');
                    }
                  },
            child: Text('Tanpa Modal Awal', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim)),
          ),
          ElevatedButton(
            onPressed: loading
                ? null
                : () async {
                    final modal = int.tryParse(ctrl.text) ?? 0;
                    setState(() => loading = true);
                    final ok = await prov.bukaShift(modal);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (ok) {
                      prov.showToast('Shift dibuka · Modal ${formatRp(modal)}');
                    } else {
                      prov.showToast('Gagal membuka shift, cek koneksi');
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Mulai Shift', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),
  );
}

// ─── Bottom Sheet Tutup Shift ────────────────────────────────────────────────

void showTutupShiftSheet(BuildContext context, AppProvider prov) {
  final ctrl = TextEditingController();
  bool loading = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final saldoSeharusnya = prov.shiftSaldoSeharusnya;

        int uangFisik() => int.tryParse(ctrl.text) ?? 0;
        int selisih() => uangFisik() - saldoSeharusnya;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.grayMid, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tutup Shift', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 4),
                Text('Hitung uang di laci dan masukkan jumlahnya',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDim)),
                const SizedBox(height: 16),

                // Ringkasan singkat
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      _SheetRow('Modal Awal', formatRp(prov.activeShift?.modalAwal ?? 0)),
                      // "Kas Masuk" sudah termasuk penjualan tunai shift ini —
                      // tidak ditampilkan terpisah supaya tidak dobel-hitung.
                      _SheetRow('Kas Masuk', '+${formatRp(prov.shiftKasMasuk)}', color: AppColors.primary),
                      _SheetRow('Kas Keluar', '-${formatRp(prov.shiftKasKeluar)}', color: AppColors.red),
                      const Divider(height: 14, color: AppColors.borderLight),
                      _SheetRow('Seharusnya Ada', formatRp(saldoSeharusnya), isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text('Uang Fisik di Laci', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDim),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Selisih realtime
                if (ctrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SelisihBadge(selisih: selisih()),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Material(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: loading
                          ? null
                          : () async {
                              setState(() => loading = true);
                              final ok = await prov.tutupShift(uangFisik());
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (ok) {
                                prov.showToast('Shift berhasil ditutup');
                              } else {
                                prov.showToast('Gagal tutup shift, cek koneksi');
                              }
                            },
                      borderRadius: BorderRadius.circular(15),
                      child: Center(
                        child: loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Tutup Shift',
                                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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
      },
    ),
  );
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isBold;

  const _SheetRow(this.label, this.value, {this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: AppColors.textSecondary))),
          Text(value,
              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  color: color ?? AppColors.text)),
        ],
      ),
    );
  }
}

class _SelisihBadge extends StatelessWidget {
  final int selisih;
  const _SelisihBadge({required this.selisih});

  @override
  Widget build(BuildContext context) {
    final isLebih = selisih > 0;
    final isPas   = selisih == 0;
    final color   = isPas ? AppColors.primary : (isLebih ? AppColors.blue : AppColors.red);
    final bgColor = isPas ? AppColors.primaryLight : (isLebih ? const Color(0xFFDBEAFE) : AppColors.redLight);
    final label   = isPas ? 'Pas' : (isLebih ? 'Lebih ${formatRp(selisih)}' : 'Kurang ${formatRp(selisih.abs())}');
    final icon    = isPas ? Icons.check_circle_outline : (isLebih ? Icons.arrow_upward : Icons.arrow_downward);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text('Selisih: $label', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
