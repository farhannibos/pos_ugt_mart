import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/db_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _konfirmCtrl = TextEditingController();

  bool _showPass = false;
  bool _showKonfirm = false;

  int _step = 0; // 0 = minta kode, 1 = masukkan OTP + password baru
  bool _loading = false;
  String _error = '';
  String _info = '';

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _konfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Username wajib diisi');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _info = '';
    });

    final result = await DbService.requestPasswordReset(username);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['ok'] != true) {
      setState(() => _error = result['pesan'] as String? ?? 'Gagal mengirim kode');
      return;
    }

    final noHpMasked = result['no_hp_masked'] as String?;
    setState(() {
      _step = 1;
      _info = 'Kode OTP telah dikirim ke WhatsApp ${noHpMasked ?? "toko"}';
    });
  }

  Future<void> _resetPassword() async {
    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text;
    final konfirm = _konfirmCtrl.text;

    if (otp.length != 6) {
      setState(() => _error = 'Kode OTP harus 6 digit');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password baru minimal 6 karakter');
      return;
    }
    if (pass != konfirm) {
      setState(() => _error = 'Konfirmasi password tidak cocok');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await DbService.verifyResetOtpAndSetPassword(
      _usernameCtrl.text.trim(),
      otp,
      pass,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['ok'] != true) {
      setState(() => _error = result['pesan'] as String? ?? 'Gagal reset password');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password berhasil direset, silakan login')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
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
                      Text(
                        'Lupa Password',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        _step == 0
                            ? 'Kode reset akan dikirim ke WA toko'
                            : 'Masukkan kode OTP & password baru',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: _step == 0 ? _buildStepUsername() : _buildStepOtp(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStepUsername() {
    return [
      Text(
        'Masukkan username akun kamu. Kode OTP 6 digit akan dikirim ke nomor WhatsApp yang terdaftar untuk toko ini.',
        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
      ),
      const SizedBox(height: 20),
      _Field(
        ctrl: _usernameCtrl,
        label: 'Username',
        hint: 'Masukkan username',
        icon: Icons.person_outline,
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ErrorBox(_error),
      ],
      const SizedBox(height: 24),
      _PrimaryButton(
        label: 'Kirim Kode ke WhatsApp',
        loading: _loading,
        onTap: _loading ? null : _requestOtp,
      ),
    ];
  }

  List<Widget> _buildStepOtp() {
    return [
      if (_info.isNotEmpty) _InfoBox(_info),
      const SizedBox(height: 16),
      _Field(
        ctrl: _otpCtrl,
        label: 'Kode OTP',
        hint: '6 digit kode',
        icon: Icons.sms_outlined,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
      ),
      const SizedBox(height: 12),
      _PasswordField(
        ctrl: _passCtrl,
        label: 'Password Baru',
        show: _showPass,
        onToggle: () => setState(() => _showPass = !_showPass),
      ),
      const SizedBox(height: 12),
      _PasswordField(
        ctrl: _konfirmCtrl,
        label: 'Konfirmasi Password Baru',
        show: _showKonfirm,
        onToggle: () => setState(() => _showKonfirm = !_showKonfirm),
      ),
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 16),
        _ErrorBox(_error),
      ],
      const SizedBox(height: 24),
      _PrimaryButton(
        label: 'Reset Password',
        loading: _loading,
        onTap: _loading ? null : _resetPassword,
      ),
      const SizedBox(height: 12),
      Center(
        child: GestureDetector(
          onTap: _loading
              ? null
              : () => setState(() {
                    _step = 0;
                    _error = '';
                    _info = '';
                    _otpCtrl.clear();
                  }),
          child: Text(
            'Kirim ulang kode',
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ),
      ),
    ];
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
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

  const _PasswordField({
    required this.ctrl,
    required this.label,
    required this.show,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: !show,
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

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.redBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.redBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String message;
  const _InfoBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryMid),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryDark)),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
