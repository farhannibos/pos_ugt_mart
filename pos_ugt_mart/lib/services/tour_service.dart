import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../theme/app_theme.dart';

const _prefKeyPending = 'tour_pending_new_user';
const _prefKeyDone    = 'tour_done_v1';

class TourService {
  // Dipanggil tepat setelah registrasi berhasil
  static Future<void> markNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyPending, true);
    // Reset flag "done" — user baru daftar harus selalu bisa lihat tour,
    // walau perangkat ini pernah menandai tour selesai/gagal sebelumnya.
    await prefs.remove(_prefKeyDone);
  }

  // Hanya true kalau user baru daftar (flag pending ada)
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyPending) == true &&
           prefs.getBool(_prefKeyDone) != true;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyPending);
    await prefs.setBool(_prefKeyDone, true);
  }

  static void show({
    required BuildContext context,
    required GlobalKey keyBeranda,
    required GlobalKey keyUsahaku,
    required GlobalKey keyKasir,
    required GlobalKey keyRiwayat,
    required GlobalKey keyProfil,
    int retriesLeft = 5,
  }) {
    // Pastikan semua key sudah ter-attach ke widget sebelum tour dimulai
    final targets = <TargetFocus>[];

    void addIfAttached(GlobalKey key, String title, String body,
        ContentAlign align, ShapeLightFocus shape) {
      if (key.currentContext != null) {
        targets.add(_target(
            key: key, title: title, body: body, align: align, shape: shape));
      }
    }

    addIfAttached(keyBeranda, 'Beranda',
        'Pantau ringkasan usahamu hari ini — penjualan, kas tunai, dan stok menipis.',
        ContentAlign.top, ShapeLightFocus.RRect);
    addIfAttached(keyKasir, 'Kasir',
        'Tap tombol ini untuk memulai transaksi penjualan baru.',
        ContentAlign.top, ShapeLightFocus.Circle);
    addIfAttached(keyUsahaku, 'Usahaku',
        'Lengkapi info toko, atur pajak, dan kelola pengaturan bisnis kamu.',
        ContentAlign.top, ShapeLightFocus.RRect);
    addIfAttached(keyRiwayat, 'Riwayat',
        'Lihat semua transaksi yang sudah dilakukan beserta detailnya.',
        ContentAlign.top, ShapeLightFocus.RRect);
    addIfAttached(keyProfil, 'Profil',
        'Kelola akun, kasir, dan pengaturan akses pengguna.',
        ContentAlign.top, ShapeLightFocus.RRect);

    if (targets.isEmpty) {
      // Widget target belum ter-attach (mis. masih transisi layout).
      // Coba lagi sebentar lagi, jangan langsung markDone — kalau ditandai
      // selesai padahal belum pernah tampil, tour tidak akan pernah muncul lagi.
      if (retriesLeft > 0) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) {
            show(
              context: context,
              keyBeranda: keyBeranda,
              keyUsahaku: keyUsahaku,
              keyKasir: keyKasir,
              keyRiwayat: keyRiwayat,
              keyProfil: keyProfil,
              retriesLeft: retriesLeft - 1,
            );
          }
        });
      }
      return;
    }

    TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF0F172A),
      opacityShadow: 0.85,
      hideSkip: true,
      paddingFocus: 8,
      focusAnimationDuration: const Duration(milliseconds: 400),
      pulseAnimationDuration: const Duration(milliseconds: 800),
      onFinish: () => markDone(),
      onSkip: () {
        markDone();
        return true;
      },
    ).show(context: context);
  }

  static TargetFocus _target({
    required GlobalKey key,
    required String title,
    required String body,
    required ContentAlign align,
    ShapeLightFocus shape = ShapeLightFocus.RRect,
    double radius = 8,
  }) {
    return TargetFocus(
      identify: key.toString(),
      keyTarget: key,
      shape: shape,
      radius: radius,
      enableOverlayTab: true,
      contents: [
        TargetContent(
          align: align,
          builder: (ctx, controller) => _TooltipCard(
            title: title,
            body: body,
            onNext: controller.next,
            onSkip: controller.skip,
          ),
        ),
      ],
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.title,
    required this.body,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onSkip,
                child: Text(
                  'Lewati',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textDim,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Lanjut →',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
