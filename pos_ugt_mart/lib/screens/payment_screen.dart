import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/ugt_widgets.dart';
import 'success_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _cashCtrl = TextEditingController();
  final _voucherCtrl = TextEditingController();
  final _dpCtrl = TextEditingController();
  bool _isProcessing = false;

  static const _methods = [
    _PayMethod(id: 'Tunai',              label: 'Tunai',   asset: 'assets/icons/ic_wallet.png'),
    _PayMethod(id: 'QRIS',               label: 'QRIS',    asset: 'assets/icons/ic_qr.png'),
    _PayMethod(id: 'Kartu Debit/Kredit', label: 'Kartu',   icon: Icons.credit_card_outlined),
    _PayMethod(id: 'Voucher',            label: 'Voucher', icon: Icons.confirmation_number_outlined),
  ];

  @override
  void dispose() {
    _cashCtrl.dispose();
    _voucherCtrl.dispose();
    _dpCtrl.dispose();
    super.dispose();
  }

  void _processPayment(AppProvider prov) {
    if (_isProcessing) return;
    if (prov.cartItemCount == 0) {
      prov.showToast('Keranjang masih kosong');
      return;
    }
    if (prov.paymentMethod == 'Tunai' && !prov.piutangMode && prov.cashAmount < prov.total) {
      prov.showToast('Uang diterima belum cukup');
      return;
    }
    setState(() => _isProcessing = true);
    prov.processPayment();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SuccessScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: Material(
              color: prov.piutangMode ? AppColors.yellow : AppColors.primary,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: () => _processPayment(prov),
                borderRadius: BorderRadius.circular(15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      prov.piutangMode ? Icons.pending_outlined : Icons.check_circle_outline,
                      color: Colors.white, size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      prov.piutangMode ? 'Catat Piutang' : 'Proses Pembayaran',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(formatRp(prov.total),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── AppBar ──
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 26, color: AppColors.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Pembayaran',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 600 : double.infinity),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [

                    // ── Total card ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Pembayaran',
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.78))),
                                  Text('${prov.cartItemCount} item · ${prov.selectedCustomer ?? 'Umum'}',
                                      style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.60))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 14),
                          _TotalRow('Subtotal', formatRp(prov.subtotal)),
                          if (prov.discount > 0) ...[
                            const SizedBox(height: 5),
                            _TotalRow('Diskon', '- ${formatRp(prov.discount)}', dim: true),
                          ],
                          if (prov.taxEnabled) ...[
                            const SizedBox(height: 5),
                            _TotalRow('PPN 11%', formatRp(prov.taxValue)),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Total',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              Text(
                                formatRp(prov.total),
                                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Label ──
                    Text('Metode Pembayaran',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 10),

                    // ── Tab selector: 4 pill buttons ──
                    Row(
                      children: _methods.map((m) {
                        final active = prov.paymentMethod == m.id;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: m == _methods.last ? 0 : 8),
                            child: GestureDetector(
                              onTap: () => prov.setPaymentMethod(m.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: active ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: active ? AppColors.primary : AppColors.border,
                                    width: active ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    m.asset != null
                                        ? Opacity(
                                            opacity: active ? 1.0 : 0.45,
                                            child: Image.asset(m.asset!, width: 20, fit: BoxFit.contain),
                                          )
                                        : Icon(m.icon, size: 20,
                                            color: active ? Colors.white : AppColors.textDim),
                                    const SizedBox(height: 4),
                                    Text(m.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: active ? Colors.white : AppColors.textMuted,
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // ── Panel aktif ──
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(prov.paymentMethod),
                        child: _buildPanel(prov),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Status Pembayaran Toggle ──
                    Text('Status Pembayaran',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _StatusChip(
                          label: 'Lunas',
                          icon: Icons.check_circle_outline,
                          active: !prov.piutangMode,
                          activeColor: AppColors.primary,
                          onTap: () => prov.setPiutangMode(false),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _StatusChip(
                          label: 'Piutang / Nyicil',
                          icon: Icons.pending_outlined,
                          active: prov.piutangMode,
                          activeColor: AppColors.yellow,
                          onTap: () => prov.setPiutangMode(true),
                        )),
                      ],
                    ),

                    if (prov.piutangMode) ...[
                      const SizedBox(height: 12),
                      _DpPanel(prov: prov, dpCtrl: _dpCtrl),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel per metode ──
  Widget _buildPanel(AppProvider prov) {
    switch (prov.paymentMethod) {
      case 'Tunai':
        return _TunaiPanel(prov: prov, cashCtrl: _cashCtrl);
      case 'QRIS':
        return _QrisPanel(prov: prov);
      case 'Kartu Debit/Kredit':
        return _KartuPanel();
      case 'Voucher':
        return _VoucherPanel(voucherCtrl: _voucherCtrl);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Tunai ──
class _TunaiPanel extends StatelessWidget {
  final AppProvider prov;
  final TextEditingController cashCtrl;
  const _TunaiPanel({required this.prov, required this.cashCtrl});

  @override
  Widget build(BuildContext context) {
    final quickCash = [prov.total, 50000, 100000, 200000];
    return UGTCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uang Diterima',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          TextField(
            controller: cashCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [_ThousandSeparatorFormatter()],
            onChanged: (v) => prov.setCashInput(v.replaceAll('.', '')),
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
            decoration: InputDecoration(
              prefixText: 'Rp  ',
              prefixStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDim),
              hintText: '0',
              hintStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDim),
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickCash.asMap().entries.map((e) {
              final label = e.key == 0 ? 'Uang pas' : formatRp(e.value);
              return GestureDetector(
                onTap: () {
                  final formatted = _ThousandSeparatorFormatter._fmt(e.value);
                  prov.setCashInput(e.value.toString());
                  cashCtrl.text = formatted;
                  cashCtrl.selection = TextSelection.collapsed(offset: formatted.length);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.primaryMid),
                  ),
                  child: Text(label,
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                ),
              );
            }).toList(),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: DashedDivider()),
          Row(
            children: [
              Text('Kembalian',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
              const Spacer(),
              Text(
                prov.cashAmount > 0
                    ? (prov.change >= 0 ? formatRp(prov.change) : '- ${formatRp(-prov.change)}')
                    : formatRp(0),
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: prov.change < 0 ? AppColors.red : AppColors.primary),
              ),
            ],
          ),
          if (prov.cashAmount > 0 && prov.change < 0)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('Uang kurang', style: GoogleFonts.inter(fontSize: 11, color: AppColors.red)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── QRIS ──
class _QrisPanel extends StatelessWidget {
  final AppProvider prov;
  const _QrisPanel({required this.prov});

  @override
  Widget build(BuildContext context) {
    final hasRealQris = prov.qrisImageUrl.isNotEmpty;
    final merchantLabel = prov.qrisAtasNama.isNotEmpty ? prov.qrisAtasNama : prov.storeName;

    return UGTCard(
      borderRadius: 18,
      child: Column(
        children: [
          const SizedBox(height: 4),
          // QR code (gambar QRIS asli jika sudah diatur, fallback ke contoh)
          Container(
            width: 200,
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: hasRealQris
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      prov.qrisImageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => CustomPaint(
                        painter: _QrPainter(),
                        size: const Size(176, 176),
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: _QrPainter(),
                    size: const Size(176, 176),
                  ),
          ),
          const SizedBox(height: 14),
          // Label merchant
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.store, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 7),
              Text(merchantLabel,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
              if (hasRealQris && prov.qrisProvider.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(prov.qrisProvider,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasRealQris
                ? 'Arahkan kamera ke kode QRIS di atas'
                : 'QRIS belum diatur — atur di menu Usahaku',
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('Total', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primaryDark)),
                const SizedBox(height: 2),
                Text(formatRp(prov.total),
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// Painter QR code realistis (pola fixed, bukan acak)
class _QrPainter extends CustomPainter {
  static const _grid = [
    [1,1,1,1,1,1,1,0,1,0,0,1,0,0,1,1,1,1,1,1,1],
    [1,0,0,0,0,0,1,0,0,0,1,0,1,0,1,0,0,0,0,0,1],
    [1,0,1,1,1,0,1,0,1,1,0,1,0,0,1,0,1,1,1,0,1],
    [1,0,1,1,1,0,1,0,0,1,0,0,1,0,1,0,1,1,1,0,1],
    [1,0,1,1,1,0,1,0,1,0,1,0,0,0,1,0,1,1,1,0,1],
    [1,0,0,0,0,0,1,0,0,1,1,0,1,0,1,0,0,0,0,0,1],
    [1,1,1,1,1,1,1,0,1,0,1,0,1,0,1,1,1,1,1,1,1],
    [0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0],
    [1,1,0,1,0,1,1,0,0,1,1,0,1,1,1,0,1,0,1,1,0],
    [0,1,0,0,1,0,0,1,1,0,0,1,0,0,0,1,0,1,0,0,1],
    [1,0,1,1,0,1,1,0,1,0,1,0,1,1,1,0,1,1,0,1,0],
    [0,1,0,0,1,0,0,1,0,1,0,1,0,0,0,1,0,0,1,0,1],
    [1,1,0,1,0,1,1,0,1,0,1,0,1,0,1,0,1,0,0,1,0],
    [0,0,0,0,0,0,0,0,1,1,0,1,0,1,0,1,0,1,0,0,1],
    [1,1,1,1,1,1,1,0,0,0,1,0,1,0,1,0,1,1,1,0,1],
    [1,0,0,0,0,0,1,0,1,0,0,1,0,1,0,1,1,0,0,1,0],
    [1,0,1,1,1,0,1,0,0,1,1,0,1,0,1,1,0,1,1,0,1],
    [1,0,1,1,1,0,1,1,1,0,0,1,0,0,0,0,1,0,0,1,0],
    [1,0,1,1,1,0,1,0,0,1,1,0,1,0,1,0,0,1,1,0,1],
    [1,0,0,0,0,0,1,0,1,0,0,1,0,1,0,1,0,0,0,1,0],
    [1,1,1,1,1,1,1,0,0,1,0,0,1,0,1,0,1,0,1,0,1],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / _grid[0].length;
    final cellH = size.height / _grid.length;
    final paint = Paint()..color = const Color(0xFF1A1A1A);

    for (int row = 0; row < _grid.length; row++) {
      for (int col = 0; col < _grid[row].length; col++) {
        if (_grid[row][col] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(col * cellW + 0.5, row * cellH + 0.5, cellW - 1, cellH - 1),
              const Radius.circular(1.5),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => false;
}

// ── Kartu ──
class _KartuPanel extends StatefulWidget {
  @override
  State<_KartuPanel> createState() => _KartuPanelState();
}

class _KartuPanelState extends State<_KartuPanel> {
  final _cardCtrl = TextEditingController();

  @override
  void dispose() {
    _cardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UGTCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info EDC
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.credit_card_outlined, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mesin EDC Tersedia',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 5,
                        children: ['BCA', 'Mandiri', 'BRI', 'BNI'].map((b) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(b, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Input nomor referensi EDC
          Text('Nomor Referensi EDC',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _cardCtrl,
            keyboardType: TextInputType.text,
            maxLength: 20,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'cth: REF001234',
              hintStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDim),
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              prefixIcon: const Icon(Icons.receipt_outlined, size: 18, color: AppColors.textDim),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Gesek atau tempel kartu pada mesin EDC, lalu masukkan nomor referensi dari struk EDC untuk konfirmasi.',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Voucher ──
class _VoucherPanel extends StatelessWidget {
  final TextEditingController voucherCtrl;
  const _VoucherPanel({required this.voucherCtrl});

  @override
  Widget build(BuildContext context) {
    return UGTCard(
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kode Voucher',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: voucherCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.inter(fontSize: 13, letterSpacing: 1),
                  decoration: InputDecoration(
                    hintText: 'UGT-XXXX-XXXX',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      final prov = context.read<AppProvider>();
                      if (voucherCtrl.text.trim().isEmpty) {
                        prov.showToast('Masukkan kode voucher terlebih dahulu');
                      } else {
                        prov.showToast('Voucher tidak valid atau belum tersedia');
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Center(child: Text('Cek',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──
class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool dim;
  const _TotalRow(this.label, this.value, {this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.70))),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(
            fontSize: 11.5, fontWeight: FontWeight.w600,
            color: dim ? Colors.white.withValues(alpha: 0.60) : Colors.white.withValues(alpha: 0.90))),
      ],
    );
  }
}

class _PayMethod {
  final String id;
  final String label;
  final IconData? icon;
  final String? asset;
  const _PayMethod({required this.id, required this.label, this.icon, this.asset});
}

// ── Status Pembayaran Chip ──
class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active ? activeColor : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : AppColors.textDim),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── DP / Bayar Sekarang Panel (for piutang) ──
class _DpPanel extends StatelessWidget {
  final AppProvider prov;
  final TextEditingController dpCtrl;

  const _DpPanel({required this.prov, required this.dpCtrl});

  @override
  Widget build(BuildContext context) {
    final sisa = prov.total - prov.piutangTerbayar;
    return UGTCard(
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.yellowLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.info_outline, size: 14, color: AppColors.yellowText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pelanggan berhutang — bayar nanti. Isi DP jika ada.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.yellowText, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('DP / Bayar Sekarang (opsional)',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: dpCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [_ThousandSeparatorFormatter()],
            onChanged: (v) {
              final digits = v.replaceAll('.', '');
              final val = int.tryParse(digits) ?? 0;
              prov.setPiutangTerbayar(val.clamp(0, prov.total));
            },
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            decoration: InputDecoration(
              prefixText: 'Rp  ',
              prefixStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDim),
              hintText: '0',
              hintStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDim),
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.yellow, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sisa Piutang',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              Text(
                formatRp(sisa < 0 ? 0 : sisa),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: sisa > 0 ? AppColors.yellow : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final number = int.tryParse(digits);
    if (number == null) return oldValue;
    final formatted = _fmt(number);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
