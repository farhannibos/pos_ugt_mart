import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _barController;

  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _barProgress;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _barController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _logoScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.06), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    _textFade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _barProgress = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _barController, curve: Curves.easeInOut));

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 250), () => _textController.forward());
    _barController.forward();

    // Data dimuat setelah login (di AppProvider.login()) agar terfilter per toko.

    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo card
            ScaleTransition(
              scale: _logoScale,
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Image.asset(
                    'assets/images/logo_bmt.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.store,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Title & subtitle
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Column(
                  children: [
                    Text(
                      'UGT MART',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Point of Sale · Kasir',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Progress bar
            Container(
              width: 120,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
              child: AnimatedBuilder(
                animation: _barProgress,
                builder: (_, __) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _barProgress.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'v2.4.0',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 1.0,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
