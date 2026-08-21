import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../services/device_id_service.dart';
import '../services/db_service.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  static const _adminWa = '628123456789'; // ganti nomor nyata

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  int _selectedPlan = 1; // 0=1bln, 1=3bln, 2=12bln
  String _deviceId = '';
  String _deviceLabel = '';
  Map<String, dynamic>? _pendingRequest;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _checkPending();
  }

  Future<void> _loadDeviceId() async {
    final id = await DeviceIdService.getDeviceId();
    final label = await DeviceIdService.getDeviceLabel();
    if (!mounted) return;
    setState(() {
      _deviceId = id;
      _deviceLabel = label;
    });
  }

  Future<void> _checkPending() async {
    final idToko = int.tryParse(context.read<AppProvider>().idToko);
    if (idToko == null) return;
    final res = await DbService.cekPengajuanLisensiPending(idToko);
    if (!mounted) return;
    setState(() {
      _pendingRequest = (res['ada'] == true) ? res : null;
    });
  }

  void _copyDeviceId(BuildContext context) {
    if (_deviceId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _deviceId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID Device disalin'), duration: Duration(seconds: 2)),
    );
  }

  static const _plans = [
    {'label': '1 Bulan',  'harga': 'Rp 99.000',  'per': 'Rp 99rb/bln',  'nominal': 99000,  'bulan': 1},
    {'label': '3 Bulan',  'harga': 'Rp 249.000', 'per': 'Rp 83rb/bln',  'nominal': 249000, 'bulan': 3, 'badge': 'Hemat 16%'},
    {'label': '12 Bulan', 'harga': 'Rp 799.000', 'per': 'Rp 66rb/bln',  'nominal': 799000, 'bulan': 12,'badge': 'Hemat 33%'},
  ];

  static const _fiturFree = [
    'Kasir & transaksi penjualan',
    'Manajemen produk & stok',
    'Riwayat penjualan',
    'Kas masuk / keluar',
    'Cetak struk',
    'Pembelian barang dari supplier',
    'Laporan & grafik penjualan',
    'Member pelanggan (maks 20)',
  ];

  static const _fiturPremium = [
    'Web Admin Panel',
    'Login web via QR Code',
    'Multi kasir & manajemen user',
    'Shift Kasir (buka & tutup shift)',
    'Grafik & analitik lebih lengkap',
    'Member pelanggan tanpa batas',
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isPremium = prov.isPremium;
    final size = MediaQuery.of(context).size;
    final hPad = size.width > 600 ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context, isPremium, prov)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildDeviceIdCard(context),
                const SizedBox(height: 20),
                if (!isPremium) ...[
                  _buildFiturSection(),
                  const SizedBox(height: 24),
                  _buildPricingSection(size),
                  const SizedBox(height: 24),
                  _buildCTA(context, prov),
                ] else ...[
                  _buildPremiumStatus(prov),
                  const SizedBox(height: 20),
                  _buildFiturSection(),
                  const SizedBox(height: 24),
                  _buildRenewButton(context, prov),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isPremium, AppProvider prov) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(height: 20),

              if (isPremium) ...[
                // Premium active state
                Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Premium Aktif ✨',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                          if (prov.planExpired != null)
                            Text('Berlaku hingga ${_fmt(prov.planExpired!)}',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Upgrade state
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text('FABIZO PREMIUM',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Kelola toko lebih\nprofesional',
                    style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
                const SizedBox(height: 8),
                Text('Web panel, shift kasir, multi kasir,\nanalitik lengkap, dan masih banyak lagi.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8), height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIdCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.smartphone_rounded, color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID Device', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                const SizedBox(height: 2),
                Text(
                  _deviceId.isEmpty ? 'Memuat...' : _deviceId,
                  style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_deviceLabel.isNotEmpty)
                  Text(_deviceLabel, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
              ],
            ),
          ),
          IconButton(
            onPressed: _deviceId.isEmpty ? null : () => _copyDeviceId(context),
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: const Color(0xFF7C3AED),
            tooltip: 'Salin ID Device',
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatus(AppProvider prov) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.workspace_premium, color: Color(0xFF7C3AED), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan Premium', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                Text('Aktif', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(100)),
            child: Text('Premium', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF7C3AED))),
          ),
        ],
      ),
    );
  }

  Widget _buildFiturSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Yang kamu dapatkan', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 12),

        // Free features
        _FeatureGroup(
          title: 'Sudah ada di Free',
          color: AppColors.primary,
          bgColor: const Color(0xFFF0FDF4),
          icon: Icons.check_circle_rounded,
          items: _fiturFree,
        ),
        const SizedBox(height: 10),

        // Premium features
        _FeatureGroup(
          title: 'Eksklusif Premium',
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF5F3FF),
          icon: Icons.workspace_premium,
          items: _fiturPremium,
          highlight: true,
        ),
      ],
    );
  }

  Widget _buildPricingSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pilih paket', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 12),
        ...List.generate(_plans.length, (i) {
          final plan = _plans[i];
          final isSelected = _selectedPlan == i;
          final badge = plan['badge'] as String?;
          return GestureDetector(
            onTap: () => setState(() => _selectedPlan = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF7C3AED) : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : AppColors.border,
                        width: 2,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 13, color: Color(0xFF7C3AED))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppColors.text,
                            )),
                        Text(plan['per'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isSelected ? Colors.white.withValues(alpha: 0.75) : AppColors.textDim,
                            )),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(plan['harga'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.text,
                          )),
                      if (badge != null)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(badge,
                              style: GoogleFonts.inter(
                                fontSize: 9.5, fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFFD97706),
                              )),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCTA(BuildContext context, AppProvider prov) {
    if (_pendingRequest != null) return _buildPendingBanner();

    final plan = _plans[_selectedPlan];
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _submitting ? null : () => _ajukanPremium(context, prov, plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text('Ajukan Premium Sekarang',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Paket dipilih: ${plan['label']} — ${plan['harga']}\nPengajuan langsung masuk ke admin untuk diverifikasi. Aktif dalam 1×24 jam setelah disetujui.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textDim, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildRenewButton(BuildContext context, AppProvider prov) {
    if (_pendingRequest != null) {
      return Column(children: [const SizedBox(height: 8), _buildPendingBanner()]);
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _submitting ? null : () => _ajukanPremium(context, prov, _plans[_selectedPlan]),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text('Ajukan Perpanjangan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingBanner() {
    final noInvoice = _pendingRequest?['no_invoice']?.toString() ?? '-';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Menunggu persetujuan admin',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
                const SizedBox(height: 2),
                Text('Invoice $noInvoice sudah diajukan. Admin akan meninjau dan mengaktifkan premium Anda.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF92400E), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ajukanPremium(BuildContext context, AppProvider prov, Map<String, Object?> plan) async {
    if (_deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Device belum siap, coba lagi sebentar')),
      );
      return;
    }
    final idToko = int.tryParse(prov.idToko);
    if (idToko == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Toko tidak valid')),
      );
      return;
    }

    setState(() => _submitting = true);
    final res = await DbService.ajukanLisensiPremium(
      idToko: idToko,
      idDevice: _deviceId,
      durasiBulan: plan['bulan'] as int,
      harga: plan['nominal'] as int,
      catatan: 'Paket ${plan['label']}',
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['pesan']?.toString() ?? 'Gagal mengajukan premium')),
      );
      return;
    }

    await _checkPending();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pengajuan terkirim (${res['no_invoice']}). Menunggu persetujuan admin.')),
    );
    _bukaWhatsAppAdmin(prov, plan, res['no_invoice']?.toString());
  }

  void _bukaWhatsAppAdmin(AppProvider prov, Map<String, Object?> plan, String? noInvoice) {
    final pesan = Uri.encodeComponent(
      'Halo Admin FABIZO! 👋\n\n'
      'Saya sudah mengajukan Premium lewat aplikasi.\n\n'
      '🏪 Nama Toko: ${prov.storeName}\n'
      '👤 Username: ${prov.kasirName}\n'
      '🆔 ID Toko: ${prov.idToko}\n'
      '📱 ID Device: $_deviceId\n'
      '📦 Paket: ${plan['label']} — ${plan['harga']}\n'
      '${noInvoice != null ? '🧾 No. Invoice: $noInvoice\n' : ''}'
      '\nMohon informasi rekening dan langkah selanjutnya. Terima kasih!',
    );
    final url = 'https://wa.me/${UpgradeScreen._adminWa}?text=$pesan';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _FeatureGroup extends StatelessWidget {
  final String title;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final List<String> items;
  final bool highlight;

  const _FeatureGroup({
    required this.title,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.items,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
                if (highlight) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('Premium only',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ...items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: Color(0x12000000))),
              ),
              child: Row(
                children: [
                  Icon(
                    highlight ? Icons.lock_open_rounded : Icons.check_rounded,
                    size: 15,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.value,
                        style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.text,
                            fontWeight: highlight ? FontWeight.w500 : FontWeight.w400)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
