import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/gradient_wave.dart';
import 'main_scaffold.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePass = true;
  bool _loading = false;
  String? _errorMsg;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _doLogin() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Username dan password wajib diisi');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final ok = await context.read<AppProvider>().login(username, password);
    if (!mounted) return;
    if (!ok) {
      setState(() { _loading = false; _errorMsg = 'Username atau password salah'; });
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScaffold(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    // Green hero area = 36% of screen height, collapses when keyboard visible
    final heroHeight = size.height * 0.36;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Animated gradient wave fills entire screen ──
          const Positioned.fill(child: GradientWave()),

          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: isWide ? 440 : double.infinity),
                child: Column(
                  children: [
                    // ── 1. Hero: logo + title — collapses when keyboard open ──
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      height: keyboardVisible ? 0.0 : heroHeight,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo — sudut sedikit melengkung, tanpa container
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/logo_bmt.png',
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.store_rounded,
                                    size: 52,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'FABIZO',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ── 2. White sheet — satu lengkungan atas, tanpa drag handle ──
                    Expanded(
                      child: SlideTransition(
                        position: _slideAnim,
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                            ),
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                28,
                                24,
                                MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header teks
                                  Text(
                                    'Masuk',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Masukkan akun Anda untuk membuka shift',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── 4. Username — satu container utuh ──
                                  _FieldLabel('Username'),
                                  const SizedBox(height: 7),
                                  _InputField(
                                    controller: _userCtrl,
                                    hint: 'Masukkan username',
                                    prefixIcon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 16),

                                  // ── 4. Password — satu container utuh ──
                                  _FieldLabel('Password'),
                                  const SizedBox(height: 7),
                                  _PasswordField(
                                    controller: _passCtrl,
                                    obscure: _obscurePass,
                                    onToggle: () => setState(
                                        () => _obscurePass = !_obscurePass),
                                  ),
                                  const SizedBox(height: 14),

                                  // Error message
                                  if (_errorMsg != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMsg!,
                                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],

                                  // Remember me + lupa password
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _rememberMe = !_rememberMe),
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 150),
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: _rememberMe
                                                    ? AppColors.primary
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                border: _rememberMe
                                                    ? null
                                                    : Border.all(
                                                        color:
                                                            AppColors.textDim,
                                                        width: 1.5),
                                              ),
                                              child: _rememberMe
                                                  ? const Icon(Icons.check,
                                                      size: 12,
                                                      color: Colors.white)
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Ingat saya',
                                              style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Lupa Password?',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 26),

                                  // ── 3. Tombol solid — tanpa gradien, shadow netral ──
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: Material(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        onTap: _loading ? null : _doLogin,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.10),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (_loading)
                                                const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              else ...[
                                                Text(
                                                  'Masuk',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ── Daftar Toko Baru ──
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text('atau', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textDim)),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: Text(
                                        'Daftar Toko Baru — Gratis',
                                        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ──

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        prefixIcon:
            Icon(prefixIcon, size: 19, color: AppColors.textDim),
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            size: 19, color: AppColors.textDim),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 19,
            color: AppColors.textDim,
          ),
        ),
        hintText: '••••••••',
        hintStyle:
            GoogleFonts.inter(fontSize: 14, color: AppColors.textDim),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
