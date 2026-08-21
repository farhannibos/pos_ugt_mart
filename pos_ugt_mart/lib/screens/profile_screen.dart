import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/ugt_widgets.dart';
import 'login_screen.dart';
import 'printer_screen.dart';
import 'qr_scanner_screen.dart';
import 'settings_screen.dart';
import 'shift_screen.dart';
import 'upgrade_screen.dart';

Color _roleColor(String role) {
  switch (role) {
    case 'Owner': return const Color(0xFF16A34A);
    case 'Admin': return const Color(0xFF8B5CF6);
    default:      return const Color(0xFF3B82F6);
  }
}

Future<void> _pickAndUploadAvatar(BuildContext context) async {
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
            Text('Foto Profil', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
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
  await prov.updateProfilePhoto(data, ext);
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isWide = MediaQuery.of(context).size.width > 600;
    final initials = prov.kasirName.isNotEmpty
        ? prov.kasirName.split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';
    final role = prov.kasirRole.isNotEmpty ? prov.kasirRole : 'Kasir';
    final roleColor = _roleColor(role);
    final loginStr = prov.loginTime != null
        ? 'Login ${prov.loginTime!.hour.toString().padLeft(2, '0')}:${prov.loginTime!.minute.toString().padLeft(2, '0')}'
        : '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Green header
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(color: AppColors.primary, height: MediaQuery.of(context).padding.top),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
                  child: SizedBox(
                    height: isWide ? 180 : 148,
                    child: Stack(
                      children: [
                        // Full-width image background
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/bg_profile_header.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                          ),
                        ),
                        // Left overlay so text stays readable
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xD0063E31), Color(0x40063E31), Colors.transparent],
                                stops: [0.0, 0.45, 0.75],
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Profil',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _pickAndUploadAvatar(context),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          alignment: Alignment.center,
                                          child: prov.fotoProfilUrl.isNotEmpty
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(20),
                                                  child: Image.network(
                                                    prov.fotoProfilUrl,
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Text(
                                                      initials,
                                                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  initials,
                                                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                                ),
                                        ),
                                        Positioned(
                                          bottom: -4,
                                          right: -4,
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                            child: const Icon(Icons.camera_alt, size: 11, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prov.kasirName,
                                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: roleColor.withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(100),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                                            ),
                                            child: Text(
                                              role,
                                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                                            ),
                                          ),
                                          if (loginStr.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              loginStr,
                                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, isWide ? 24 : 104),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Stat row
                Row(
                  children: [
                    Expanded(
                      child: UGTCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Transaksi Hari Ini', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
                            const SizedBox(height: 3),
                            Text('${prov.todayTrxCount}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
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
                            Text('Penjualan Hari Ini', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textDim)),
                            const SizedBox(height: 3),
                            Text(formatRp(prov.todayTotalPenjualan), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Informasi Toko', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                const SizedBox(height: 10),
                UGTCard(
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/ic_store.png',
                        width: 46,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prov.storeName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                            const SizedBox(height: 3),
                            Text(prov.alamatToko, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                            Text(prov.terminalName, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Langganan card
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradeScreen())),
                  child: UGTCard(
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/icons/ic_premium.png',
                          width: 44,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prov.isPremium ? 'Premium Aktif' : 'Plan Gratis',
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700,
                                    color: prov.isPremium ? const Color(0xFF7C3AED) : AppColors.text),
                              ),
                              Text(
                                prov.isPremium ? 'Semua fitur tersedia' : 'Upgrade untuk Web Panel & lebih',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDim),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.placeholder),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Pengaturan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                const SizedBox(height: 10),
                UGTCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _SettingItem(
                        asset: 'assets/icons/ic_shift.png',
                        label: 'Shift Kasir',
                        trailing: prov.isPremium
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                if (prov.activeShift != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('AKTIF', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                  )
                                else
                                  const SizedBox.shrink(),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 16, color: AppColors.placeholder),
                              ])
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Premium', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B))),
                              ),
                        showBorder: true,
                        onTap: () {
                          if (!prov.isPremium) {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradeScreen()));
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftScreen()));
                        },
                      ),
                      _SettingItem(
                        asset: 'assets/icons/ic_web_login.png',
                        label: 'Login Web Panel (Scan QR)',
                        trailing: prov.isPremium
                            ? const Icon(Icons.chevron_right, size: 16, color: AppColors.placeholder)
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Premium', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B))),
                              ),
                        showBorder: true,
                        onTap: () {
                          if (!prov.isPremium) {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpgradeScreen()));
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
                        },
                      ),
                      _SettingItem(
                        asset: 'assets/icons/ic_struk.png',
                        label: 'Printer Struk',
                        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textDim),
                        showBorder: true,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrinterScreen())),
                      ),
                      _SettingItem(
                        asset: 'assets/icons/ic_settings.png',
                        label: 'Pengaturan Aplikasi',
                        trailing: const Icon(Icons.chevron_right, size: 16, color: AppColors.placeholder),
                        showBorder: true,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                      _SettingItem(
                        asset: 'assets/icons/ic_bantuan.png',
                        label: 'Bantuan & Panduan',
                        trailing: const Icon(Icons.chevron_right, size: 16, color: AppColors.placeholder),
                        showBorder: false,
                        onTap: () => prov.showToast('Fitur bantuan segera hadir'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Logout
                Material(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: () async {
                      await prov.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.redBorder, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/icons/ic_logout.png', width: 22, fit: BoxFit.contain),
                          const SizedBox(width: 9),
                          Text(
                            'Keluar / Logout',
                            style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'FABIZO POS · v2.4.0',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder),
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

class _SettingItem extends StatelessWidget {
  final String asset;
  final String label;
  final Widget trailing;
  final bool showBorder;
  final VoidCallback? onTap;

  const _SettingItem({
    required this.asset,
    required this.label,
    required this.trailing,
    required this.showBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showBorder ? const Border(bottom: BorderSide(color: AppColors.borderLight)) : null,
        ),
        child: Row(
          children: [
            Image.asset(
              asset,
              width: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.text)),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
