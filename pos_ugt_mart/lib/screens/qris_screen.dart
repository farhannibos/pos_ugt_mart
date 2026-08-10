import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/ugt_widgets.dart';

class QrisScreen extends StatefulWidget {
  const QrisScreen({super.key});

  @override
  State<QrisScreen> createState() => _QrisScreenState();
}

class _QrisScreenState extends State<QrisScreen> {
  int _tab = 0; // 0 = QRIS, 1 = Rekening Bank

  static const _qrisProviders = ['GoPay', 'OVO', 'DANA', 'ShopeePay', 'LinkAja', 'Lainnya'];
  static const _banks = ['BCA', 'Mandiri', 'BRI', 'BNI', 'BSI', 'Lainnya'];

  String? _qrisProviderSel;
  final _qrisNamaCtrl = TextEditingController();
  final _qrisHpCtrl = TextEditingController();
  Uint8List? _pickedImageBytes;
  String? _pickedImageExt;
  bool _savingQris = false;

  String? _bankSel;
  final _bankRekeningCtrl = TextEditingController();
  final _bankAtasNamaCtrl = TextEditingController();
  bool _savingBank = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<AppProvider>();
    _qrisProviderSel = prov.qrisProvider.isNotEmpty ? prov.qrisProvider : null;
    _qrisNamaCtrl.text = prov.qrisAtasNama;
    _qrisHpCtrl.text = prov.qrisNoHp;
    _bankSel = prov.bankNama.isNotEmpty ? prov.bankNama : null;
    _bankRekeningCtrl.text = prov.bankNoRekening;
    _bankAtasNamaCtrl.text = prov.bankAtasNama;
  }

  @override
  void dispose() {
    _qrisNamaCtrl.dispose();
    _qrisHpCtrl.dispose();
    _bankRekeningCtrl.dispose();
    _bankAtasNamaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1000);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExt = ext;
    });
  }

  Future<void> _saveQris() async {
    final prov = context.read<AppProvider>();
    if (_qrisProviderSel == null || _qrisProviderSel!.isEmpty) {
      prov.showToast('Pilih penyedia QRIS terlebih dahulu');
      return;
    }
    if (_qrisNamaCtrl.text.trim().isEmpty) {
      prov.showToast('Isi atas nama QRIS');
      return;
    }
    if (_qrisHpCtrl.text.trim().isEmpty) {
      prov.showToast('Isi nomor HP');
      return;
    }
    if (_pickedImageBytes == null && prov.qrisImageUrl.isEmpty) {
      prov.showToast('Upload gambar QRIS terlebih dahulu');
      return;
    }
    setState(() => _savingQris = true);
    final ok = await prov.saveQris(
      provider: _qrisProviderSel!,
      atasNama: _qrisNamaCtrl.text,
      noHp: _qrisHpCtrl.text,
      imageBytes: _pickedImageBytes,
      imageExt: _pickedImageExt,
    );
    if (!mounted) return;
    setState(() => _savingQris = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _saveBank() async {
    final prov = context.read<AppProvider>();
    if (_bankSel == null || _bankSel!.isEmpty) {
      prov.showToast('Pilih nama bank terlebih dahulu');
      return;
    }
    if (_bankRekeningCtrl.text.trim().isEmpty) {
      prov.showToast('Isi nomor rekening');
      return;
    }
    if (_bankAtasNamaCtrl.text.trim().isEmpty) {
      prov.showToast('Isi atas nama rekening');
      return;
    }
    setState(() => _savingBank = true);
    final ok = await prov.saveRekening(
      bank: _bankSel!,
      noRekening: _bankRekeningCtrl.text,
      atasNama: _bankAtasNamaCtrl.text,
    );
    if (!mounted) return;
    setState(() => _savingBank = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: UGTAppBar(
        title: 'Tambah QRIS/Rekening',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Tab selector ──
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(child: _TabButton(label: 'QRIS', active: _tab == 0, onTap: () => setState(() => _tab = 0))),
                  const SizedBox(width: 4),
                  Expanded(child: _TabButton(label: 'Rekening Bank', active: _tab == 1, onTap: () => setState(() => _tab = 1))),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_tab == 0) _buildQrisForm() else _buildBankForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildQrisForm() {
    final prov = context.watch<AppProvider>();
    return UGTCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Penyedia QRIS'),
          const SizedBox(height: 6),
          _Dropdown(
            value: _qrisProviderSel,
            hint: 'Pilih Penyedia QRIS',
            items: _qrisProviders,
            onChanged: (v) => setState(() => _qrisProviderSel = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Atas Nama'),
          const SizedBox(height: 6),
          _TextInput(controller: _qrisNamaCtrl, hint: 'Nama'),
          const SizedBox(height: 14),
          _FieldLabel('Nomor HP'),
          const SizedBox(height: 6),
          _TextInput(controller: _qrisHpCtrl, hint: 'Nomor', keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _FieldLabel('Upload QRIS'),
          const SizedBox(height: 8),
          _UploadBox(
            pickedBytes: _pickedImageBytes,
            existingUrl: prov.qrisImageUrl,
            onTap: _pickImage,
          ),
          const SizedBox(height: 8),
          Text(
            'Unggah gambar atau file QRIS dari galeri atau aplikasi mobile banking Anda.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: UGTButton(
              label: _savingQris ? 'Menyimpan...' : 'Simpan',
              onTap: _savingQris ? () {} : _saveQris,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankForm() {
    return UGTCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Nama Bank'),
          const SizedBox(height: 6),
          _Dropdown(
            value: _bankSel,
            hint: 'Pilih Nama Bank',
            items: _banks,
            onChanged: (v) => setState(() => _bankSel = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel('Nomor Rekening'),
          const SizedBox(height: 6),
          _TextInput(
            controller: _bankRekeningCtrl,
            hint: 'Nomor Rekening',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 14),
          _FieldLabel('Atas Nama'),
          const SizedBox(height: 6),
          _TextInput(controller: _bankAtasNamaCtrl, hint: 'Nama Pemilik Rekening'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: UGTButton(
              label: _savingBank ? 'Menyimpan...' : 'Simpan',
              onTap: _savingBank ? () {} : _saveBank,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets lokal ──────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary : Colors.transparent, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.primaryDark : AppColors.textDim,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text),
        children: [
          TextSpan(text: text),
          TextSpan(text: ' *', style: GoogleFonts.inter(color: AppColors.red)),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({required this.value, required this.hint, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Pastikan value lama (mis. hasil input manual sebelumnya) tetap muncul walau di luar daftar preset.
    final options = value != null && value!.isNotEmpty && !items.contains(value)
        ? [...items, value!]
        : items;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textDim)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textDim),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
          items: options
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final Uint8List? pickedBytes;
  final String existingUrl;
  final VoidCallback onTap;

  const _UploadBox({required this.pickedBytes, required this.existingUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = pickedBytes != null || existingUrl.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(color: AppColors.primary, radius: 16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: hasImage
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: pickedBytes != null
                          ? Image.memory(pickedBytes!, height: 130, fit: BoxFit.contain)
                          : Image.network(
                              existingUrl,
                              height: 130,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textDim),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('Ganti Gambar',
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 34, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text('Upload QRIS',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()..addRRect(rrect);
    final dashPath = Path();
    const dashLen = 6.0;
    const gapLen = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLen).clamp(0.0, metric.length);
        dashPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashLen + gapLen;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
