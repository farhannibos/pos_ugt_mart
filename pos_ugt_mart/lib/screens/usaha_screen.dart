import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import 'printer_screen.dart';
import 'qris_screen.dart';
import 'upgrade_screen.dart';

class UsahaScreen extends StatelessWidget {
  const UsahaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final taxRate = prov.taxRate;
    final isPremium = prov.isPremium;

    final taxLabel = taxRate > 0
        ? '${taxRate % 1 == 0 ? taxRate.toInt() : taxRate}%'
        : 'Tidak Aktif';

    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, isWide ? 40 : 104),
          children: [
            // Judul
            Text(
              'Usahaku',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 20),

            // ── Card: Informasi Usaha ─────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Informasi Usaha',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showEditInfoSheet(context, prov),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ubah',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_outlined,
                                  size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Logo toko
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickAndUploadLogo(context),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: prov.logoTokoUrl.isNotEmpty
                                  ? Image.network(
                                      prov.logoTokoUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _StoreInitials(storeName: prov.storeName),
                                    )
                                  : _StoreInitials(storeName: prov.storeName),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Info rows
                  _InfoRow('Nama Usaha', prov.storeName),
                  _InfoRow('Nama Pemilik',
                      prov.namaPemilik.isNotEmpty ? prov.namaPemilik : '-'),
                  _InfoRow('Lokasi Usaha',
                      prov.alamatToko.isNotEmpty ? prov.alamatToko : '-'),
                  _InfoRow('Nomor Handphone',
                      prov.noHp.isNotEmpty ? prov.noHp : '-',
                      isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Card: Pajak ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _showPpnSheet(context, prov.taxRate),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/icons/ic_tax.png',
                                width: 44,
                                height: 44,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pajak (${taxRate > 0 ? 'Aktif' : 'Tidak Aktif'})',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      taxLabel,
                                      style: GoogleFonts.inter(
                                          fontSize: 13, color: AppColors.textDim),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Switch(
                    value: taxRate > 0,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => prov.setTaxEnabled(v),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Card: QRIS & Rekening ─────────────────────────────────────
            _TapCard(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QrisScreen())),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icons/ic_qr.png',
                    width: 44,
                    height: 44,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QRIS & Rekening',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          prov.qrisImageUrl.isNotEmpty ? 'QRIS aktif' : 'Belum diatur',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textDim, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Card: Atur Struk ──────────────────────────────────────────
            _TapCard(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrinterScreen())),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icons/ic_struk.png',
                    width: 44,
                    height: 44,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Atur Struk',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textDim, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Card: Langganan ───────────────────────────────────────────
            _TapCard(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UpgradeScreen())),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPremium ? 'Langganan Premium' : 'Langganan',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPremium ? 'Semua fitur aktif' : 'Plan Gratis',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textDim),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPremium
                              ? const Color(0xFFEDE9FE)
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPremium ? 'Premium' : 'Free',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isPremium
                                ? const Color(0xFF7C3AED)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textDim, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  void _showEditInfoSheet(BuildContext context, AppProvider prov) {
    final namaCtrl    = TextEditingController(text: prov.storeName);
    final pemilikCtrl = TextEditingController(text: prov.namaPemilik);
    final lokasiCtrl  = TextEditingController(text: prov.alamatToko);
    final hpCtrl      = TextEditingController(text: prov.noHp);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
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
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Ubah Informasi Usaha',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const SizedBox(height: 16),
              _SheetField(label: 'Nama Usaha', ctrl: namaCtrl,
                  hint: 'Contoh: FABIZO'),
              const SizedBox(height: 12),
              _SheetField(label: 'Nama Pemilik', ctrl: pemilikCtrl,
                  hint: 'Nama pemilik toko'),
              const SizedBox(height: 12),
              _SheetField(label: 'Lokasi Usaha', ctrl: lokasiCtrl,
                  hint: 'Contoh: Banyuwangi', maxLines: 2),
              const SizedBox(height: 12),
              _SheetField(
                label: 'Nomor Handphone',
                ctrl: hpCtrl,
                hint: '+628xxxxxxxx',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      context.read<AppProvider>().setInfoUsaha(
                        nama:    namaCtrl.text,
                        pemilik: pemilikCtrl.text,
                        lokasi:  lokasiCtrl.text,
                        hp:      hpCtrl.text,
                      );
                      Navigator.of(ctx).pop();
                    },
                    child: Center(
                      child: Text('Simpan',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPpnSheet(BuildContext context, double currentRate) {
    final ctrl = TextEditingController(
      text: currentRate == 0
          ? ''
          : (currentRate % 1 == 0
              ? currentRate.toInt().toString()
              : currentRate.toString()),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
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
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Pengaturan Pajak',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              Text('Isi 0 atau kosongkan untuk nonaktifkan pajak',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textDim)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,3}(\.\d{0,2})?'))
                ],
                style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDim),
                  suffixText: '%',
                  suffixStyle: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [0, 5, 10, 11, 12].map((v) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      ctrl.text = v == 0 ? '' : v.toString();
                      ctrl.selection = TextSelection.collapsed(
                          offset: ctrl.text.length);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.primaryMid),
                      ),
                      child: Text('$v%',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      final val = double.tryParse(ctrl.text.trim()) ?? 0;
                      context.read<AppProvider>().setTaxRate(val);
                      Navigator.of(ctx).pop();
                    },
                    child: Center(
                      child: Text('Simpan',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StoreInitials extends StatelessWidget {
  final String storeName;
  const _StoreInitials({required this.storeName});

  @override
  Widget build(BuildContext context) => Center(
        child: storeName.isNotEmpty
            ? Text(
                storeName.split(' ').map((w) => w[0]).take(2).join().toUpperCase(),
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
              )
            : const Icon(Icons.store, size: 36, color: Colors.white),
      );
}

Future<void> _pickAndUploadLogo(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Foto Usaha', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: Text('Ambil Foto', style: GoogleFonts.inter(fontSize: 14)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: Text('Pilih dari Galeri', style: GoogleFonts.inter(fontSize: 14)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return;

  final picker = ImagePicker();
  final file = await picker.pickImage(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 85);
  if (file == null) return;
  if (!context.mounted) return;
  final prov = context.read<AppProvider>();

  final data = await file.readAsBytes();
  final ext = file.name.split('.').last.toLowerCase();
  prov.showToast('Mengunggah foto...');
  await prov.updateTokoLogo(data, ext);
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: child,
      );
}

class _TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: child,
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow(this.label, this.value, {this.isLast = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textDim)),
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;

  const _SheetField({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
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
            textCapitalization: keyboardType == TextInputType.phone
                ? TextCapitalization.none
                : TextCapitalization.words,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
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
