import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _cardCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _textCtrl;
  late AnimationController _barCtrl;
  late AnimationController _sparkleCtrl;

  // Card
  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;

  // Logo
  late Animation<double> _logoOpacity;

  // Shimmer
  late Animation<double> _shimmerPos;

  // Particles
  late Animation<double> _particleAnim;

  // Text
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  // Progress bar
  late Animation<double> _barProgress;

  // Sparkle
  late Animation<double> _sparklePulse;

  @override
  void initState() {
    super.initState();

    _cardCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _logoCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _shimmerCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _particleCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _barCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _sparkleCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
          ..repeat(reverse: true);

    // Card: scale bounce masuk
    _cardScale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.25, end: 1.07)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 65),
      TweenSequenceItem(
          tween: Tween(begin: 1.07, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 35),
    ]).animate(_cardCtrl);

    _cardOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardCtrl, curve: const Interval(0, 0.4)));

    // Logo fade in
    _logoOpacity = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));

    // Shimmer sapuan kiri ke kanan
    _shimmerPos = Tween(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    // Particles ledak
    _particleAnim = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _particleCtrl, curve: Curves.easeOut));

    // Teks muncul
    _textFade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween(begin: const Offset(0, 0.45), end: Offset.zero).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    // Progress bar neon
    _barProgress = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut));

    // Sparkle kedip
    _sparklePulse = Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _sparkleCtrl, curve: Curves.easeInOut));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    _runSequence();
  }

  Future<void> _runSequence() async {
    // 1. Card muncul
    await _cardCtrl.forward();

    // 2. Logo fade in + shimmer mulai bersamaan
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    _shimmerCtrl.forward();

    // 3. Partikel meledak saat shimmer hampir selesai
    await Future.delayed(const Duration(milliseconds: 400));
    _particleCtrl.forward();

    // 4. Teks muncul
    await Future.delayed(const Duration(milliseconds: 200));
    _textCtrl.forward();

    // 5. Progress bar neon
    await Future.delayed(const Duration(milliseconds: 250));
    _barCtrl.forward();

    // 6. Navigate ke login
    await Future.delayed(const Duration(milliseconds: 1700));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _logoCtrl.dispose();
    _shimmerCtrl.dispose();
    _particleCtrl.dispose();
    _textCtrl.dispose();
    _barCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF052E24),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF052E24), Color(0xFF0A5240)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Sparkle bintang pojok (persis seperti video)
              _SparkleOverlay(pulse: _sparklePulse),

              Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ── Logo area ──────────────────────────────────────
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Partikel meledak di belakang card
                              AnimatedBuilder(
                                animation: _particleAnim,
                                builder: (_, __) => CustomPaint(
                                  size: const Size(220, 220),
                                  painter:
                                      _ParticlePainter(_particleAnim.value),
                                ),
                              ),

                              // Card rounded + logo
                              AnimatedBuilder(
                                animation: _cardCtrl,
                                builder: (_, child) => Opacity(
                                  opacity: _cardOpacity.value,
                                  child: Transform.scale(
                                    scale: _cardScale.value,
                                    child: child,
                                  ),
                                ),
                                child: Container(
                                  width: 148,
                                  height: 148,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D5540),
                                    borderRadius: BorderRadius.circular(36),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF4ADE80)
                                            .withValues(alpha: 0.08),
                                        blurRadius: 32,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(36),
                                    child: AnimatedBuilder(
                                      animation: Listenable.merge(
                                          [_logoCtrl, _shimmerCtrl]),
                                      builder: (_, child) => Opacity(
                                        opacity: _logoOpacity.value,
                                        child: ShaderMask(
                                          shaderCallback: (rect) {
                                            final x = _shimmerPos.value;
                                            return LinearGradient(
                                              begin: Alignment(x - 0.6, -0.5),
                                              end: Alignment(x + 0.6, 0.5),
                                              colors: [
                                                Colors.white.withValues(alpha: 0.0),
                                                Colors.white.withValues(alpha: 0.5),
                                                Colors.white.withValues(alpha: 0.0),
                                              ],
                                            ).createShader(rect);
                                          },
                                          blendMode: BlendMode.srcATop,
                                          child: child,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(26),
                                        child: Image.asset(
                                          'assets/images/logo_bmt.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.store,
                                                  size: 60,
                                                  color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Teks ──────────────────────────────────────────
                        FadeTransition(
                          opacity: _textFade,
                          child: SlideTransition(
                            position: _textSlide,
                            child: Column(
                              children: [
                                Text(
                                  'UGT MART',
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Point of Sale · Kasir',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Progress bar neon hijau ───────────────────────
                        AnimatedBuilder(
                          animation: _barProgress,
                          builder: (_, __) =>
                              _NeonBar(progress: _barProgress.value),
                        ),
                      ],
                    ),
                  ),

                  // Versi
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Text(
                      'v2.4.0',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Neon progress bar ─────────────────────────────────────────────────────────

class _NeonBar extends StatelessWidget {
  final double progress;
  const _NeonBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF4ADE80)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.7),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Partikel meledak ──────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final double progress;

  static final _rng = Random(7);
  static final _particles = List.generate(24, (_) {
    final angle = _rng.nextDouble() * 2 * pi;
    final dist = 62.0 + _rng.nextDouble() * 48;
    final r = 2.0 + _rng.nextDouble() * 3.5;
    final green = _rng.nextInt(3) != 0; // kebanyakan hijau
    return (a: angle, d: dist, r: r, g: green);
  });

  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in _particles) {
      final eased = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
      final dist = p.d * eased;
      // Opacity: muncul cepat, hilang perlahan
      final opacity = progress < 0.4
          ? (progress / 0.4).clamp(0.0, 1.0)
          : (1 - ((progress - 0.4) / 0.6)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = (p.g ? const Color(0xFF4ADE80) : Colors.white)
            .withValues(alpha: opacity * 0.9)
        ..style = PaintingStyle.fill;

      final pos = Offset(
        center.dx + cos(p.a) * dist,
        center.dy + sin(p.a) * dist,
      );
      canvas.drawCircle(pos, p.r * (1 - eased * 0.25), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ── Sparkle bintang ───────────────────────────────────────────────────────────

class _SparkleOverlay extends StatelessWidget {
  final Animation<double> pulse;
  const _SparkleOverlay({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Stack(
        children: [
          // Pojok kanan bawah — sama seperti di video
          Positioned(
            bottom: 56,
            right: 30,
            child: _Star(size: 16, opacity: pulse.value),
          ),
          // Pojok kanan atas — kecil
          Positioned(
            top: 72,
            right: 44,
            child: _Star(size: 9, opacity: (1.0 - pulse.value + 0.35).clamp(0.1, 1.0)),
          ),
          // Kiri tengah — samar
          Positioned(
            top: 160,
            left: 24,
            child: _Star(size: 7, opacity: pulse.value * 0.5),
          ),
        ],
      ),
    );
  }
}

class _Star extends StatelessWidget {
  final double size;
  final double opacity;
  const _Star({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity.clamp(0.05, 1.0),
        child: CustomPaint(
          size: Size(size, size),
          painter: _StarPainter(),
        ),
      );
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Bintang 4 titik (persis seperti di video)
    final path = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx + cx * 0.18, cy - cy * 0.18)
      ..lineTo(size.width, cy)
      ..lineTo(cx + cx * 0.18, cy + cy * 0.18)
      ..lineTo(cx, size.height)
      ..lineTo(cx - cx * 0.18, cy + cy * 0.18)
      ..lineTo(0, cy)
      ..lineTo(cx - cx * 0.18, cy - cy * 0.18)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
