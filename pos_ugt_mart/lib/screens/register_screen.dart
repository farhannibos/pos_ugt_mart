import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../services/db_service.dart';
import 'main_scaffold.dart';
import '../services/tour_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaTokoCtrl  = TextEditingController();
  final _alamatCtrl    = TextEditingController();
  final _noHpCtrl      = TextEditingController();
  final _namaOwnerCtrl = TextEditingController();
  final _usernameCtrl  = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _konfirmCtrl   = TextEditingController();

  bool _showPass    = false;
  bool _showKonfirm = false;
  bool _loading     = false;
  String _error     = '';

  @override
  void dispose() {
    _namaTokoCtrl.dispose();
    _alamatCtrl.dispose();
    _noHpCtrl.dispose();
    _namaOwnerCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _konfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _daftar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = ''; });

    final result = await DbService.registerToko(
      namaToko:   _namaTokoCtrl.text.trim(),
      alamat:     _alamatCtrl.text.trim(),
      noHp:       _noHpCtrl.text.trim(),
      namaOwner:  _namaOwnerCtrl.text.trim(),
      username:   _usernameCtrl.text.trim(),
      password:   _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['ok'] != true) {
      setState(() => _error = result['pesan'] as String? ?? 'Pendaftaran gagal');
      return;
    }

    // Auto-login setelah daftar
    final prov = context.read<AppProvider>();
    final loginOk = await prov.login(_usernameCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;

    if (loginOk) {
      await TourService.markNewUser(); // tandai user baru → tour akan muncul
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScaffold()),
        (route) => false,
      );
    } else {
      setState(() => _error = 'Akun dibuat, tapi gagal login otomatis. Silakan login manual.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daftar Toko Baru', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('Gratis selamanya untuk fitur dasar', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  children: [
                    _SectionLabel('Informasi Toko'),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _namaTokoCtrl,
                      label: 'Nama Toko',
                      hint: 'contoh: Toko Maju Jaya',
                      icon: Icons.storefront_outlined,
                      validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _alamatCtrl,
                      label: 'Alamat',
                      hint: 'Jl. Contoh No.1, Kota',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _noHpCtrl,
                      label: 'No. HP / WhatsApp',
                      hint: '08xxxxxxxxxx',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => v!.trim().length < 9 ? 'No. HP tidak valid' : null,
                    ),

                    const SizedBox(height: 24),
                    _SectionLabel('Akun Owner'),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _namaOwnerCtrl,
                      label: 'Nama Lengkap',
                      hint: 'Nama pemilik toko',
                      icon: Icons.person_outline,
                      validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      ctrl: _usernameCtrl,
                      label: 'Username',
                      hint: 'Digunakan untuk login',
                      icon: Icons.badge_outlined,
                      validator: (v) {
                        if (v!.trim().length < 4) return 'Minimal 4 karakter';
                        if (v.contains(' ')) return 'Tidak boleh ada spasi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      ctrl: _passCtrl,
                      label: 'Password',
                      show: _showPass,
                      onToggle: () => setState(() => _showPass = !_showPass),
                      validator: (v) => v!.length < 6 ? 'Minimal 6 karakter' : null,
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      ctrl: _konfirmCtrl,
                      label: 'Konfirmasi Password',
                      show: _showKonfirm,
                      onToggle: () => setState(() => _showKonfirm = !_showKonfirm),
                      validator: (v) => v != _passCtrl.text ? 'Password tidak cocok' : null,
                    ),

                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.redBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.redBorder),
                        ),
                        child: Text(_error, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.red)),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _daftar,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Daftar Sekarang', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('GRATIS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Daftar gratis, tidak perlu kartu kredit.\nUpgrade ke Premium kapan saja untuk fitur lengkap.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textDim, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.3),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.placeholder),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textDim),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.ctrl,
    required this.label,
    required this.show,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: !show,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: '••••••',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.placeholder),
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.textDim),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textDim),
            ),
          ),
        ),
      ],
    );
  }
}
