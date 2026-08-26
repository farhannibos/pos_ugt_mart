import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/ugt_widgets.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  // Nomor admin sama dengan yang dipakai di upgrade_screen.dart — ganti nomor
  // nyata di kedua tempat kalau nomor admin berubah.
  static const _adminWa = '628123456789';

  static const _panduan = [
    _HelpEntry(
      icon: Icons.play_circle_outline,
      title: 'Buka Shift',
      body: 'Sebelum mulai transaksi, buka shift dulu di menu Profil > Shift Kasir. '
          'Masukkan modal awal kas di laci (boleh dikosongkan kalau tidak ada modal).',
    ),
    _HelpEntry(
      icon: Icons.point_of_sale_outlined,
      title: 'Transaksi Baru',
      body: 'Tekan tombol "Transaksi Baru" di Beranda atau ikon Kasir, pilih produk '
          'atau scan barcode, lalu tekan Bayar dan pilih metode pembayaran.',
    ),
    _HelpEntry(
      icon: Icons.receipt_long_outlined,
      title: 'Cetak / Bagikan Struk',
      body: 'Setelah transaksi selesai, struk bisa langsung dicetak (kalau printer '
          'Bluetooth sudah disambungkan di Usahaku > Atur Printer) atau dibagikan sebagai PDF.',
    ),
    _HelpEntry(
      icon: Icons.pending_outlined,
      title: 'Piutang (Kredit)',
      body: 'Pilih metode "Kredit" saat bayar untuk transaksi yang belum lunas. '
          'Lunasi lewat menu Riwayat > pilih transaksi berstatus Piutang > Lunasi Piutang.',
    ),
    _HelpEntry(
      icon: Icons.inventory_2_outlined,
      title: 'Kelola Produk & Stok',
      body: 'Tambah, edit, atau hapus produk di Usahaku > Kelola Produk. '
          'Stok otomatis berkurang tiap ada transaksi.',
    ),
    _HelpEntry(
      icon: Icons.stop_circle_outlined,
      title: 'Tutup Shift',
      body: 'Di akhir shift, buka Profil > Shift Kasir > Tutup Shift. Cek rincian kas, '
          'lalu tekan Tutup Shift — kamu akan otomatis logout dan wajib login lagi untuk shift berikutnya.',
    ),
  ];

  static const _faq = [
    _HelpEntry(
      icon: Icons.bluetooth_disabled,
      title: 'Printer Bluetooth tidak terhubung?',
      body: 'Pastikan printer sudah menyala dan sudah di-pairing di pengaturan Bluetooth '
          'HP/tablet, lalu buka Usahaku > Atur Printer dan pilih printernya. Kalau tetap '
          'gagal, struk otomatis dialihkan ke dialog cetak PDF.',
    ),
    _HelpEntry(
      icon: Icons.sync_problem_outlined,
      title: 'Transaksi tidak muncul di riwayat?',
      body: 'Cek koneksi internet — transaksi butuh koneksi untuk tersimpan ke server. '
          'Tarik layar Beranda ke bawah untuk memuat ulang data.',
    ),
    _HelpEntry(
      icon: Icons.lock_reset_outlined,
      title: 'Lupa password, bagaimana?',
      body: 'Di halaman Login, tekan "Lupa Password" lalu ikuti instruksi reset lewat '
          'nomor WhatsApp yang terdaftar.',
    ),
    _HelpEntry(
      icon: Icons.credit_score_outlined,
      title: 'Kenapa piutang tidak bisa dilunasi?',
      body: 'Piutang hanya bisa dilunasi lewat menu Riwayat pada transaksi berstatus '
          '"Piutang". Kalau transaksinya sudah "Lunas", berarti memang tidak perlu dilunasi lagi.',
    ),
    _HelpEntry(
      icon: Icons.workspace_premium_outlined,
      title: 'Bagaimana cara upgrade ke Premium?',
      body: 'Buka Profil > Upgrade ke Premium, pilih paket, lalu ikuti instruksi '
          'konfirmasi pembayaran lewat WhatsApp admin.',
    ),
  ];

  void _hubungiAdmin() {
    final pesan = Uri.encodeComponent('Halo Admin FABIZO! 👋\n\nSaya butuh bantuan terkait aplikasi POS.');
    launchUrl(Uri.parse('https://wa.me/$_adminWa?text=$pesan'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
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
                      'Bantuan & Panduan',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _SectionLabel('Panduan Cepat'),
                const SizedBox(height: 10),
                UGTCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: _panduan.asMap().entries.map((e) => _HelpTile(
                      entry: e.value,
                      showBorder: e.key < _panduan.length - 1,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 22),
                _SectionLabel('Pertanyaan Umum'),
                const SizedBox(height: 10),
                UGTCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: _faq.asMap().entries.map((e) => _HelpTile(
                      entry: e.value,
                      showBorder: e.key < _faq.length - 1,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 22),
                _SectionLabel('Masih Butuh Bantuan?'),
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: _hubungiAdmin,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_outlined, color: Color(0xFF16A34A), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hubungi Admin via WhatsApp',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF15803D))),
                                const SizedBox(height: 2),
                                Text('Belum ketemu jawabannya? Chat langsung ke admin.',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A))),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF16A34A)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpEntry {
  final IconData icon;
  final String title;
  final String body;
  const _HelpEntry({required this.icon, required this.title, required this.body});
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted));
  }
}

class _HelpTile extends StatefulWidget {
  final _HelpEntry entry;
  final bool showBorder;
  const _HelpTile({required this.entry, required this.showBorder});

  @override
  State<_HelpTile> createState() => _HelpTileState();
}

class _HelpTileState extends State<_HelpTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: widget.showBorder ? const Border(bottom: BorderSide(color: AppColors.borderLight)) : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.entry.icon, size: 17, color: AppColors.primary),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(widget.entry.title,
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.textDim),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Padding(
                padding: const EdgeInsets.only(left: 45),
                child: Text(widget.entry.body,
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textDim, height: 1.5)),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
