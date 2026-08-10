import 'package:flutter/material.dart';
import 'dart:math' as math;

class GradientWave extends StatefulWidget {
  final List<Color> colors;
  const GradientWave({super.key, this.colors = _defaultColors});

  static const _defaultColors = [
    Color(0xFF0A5C2A), // deep forest green — base
    Color(0xFF16A34A), // primary green
    Color(0xFF22C55E), // medium green
    Color(0xFF4ADE80), // light green
    Color(0xFFBBF7D0), // mint
    Color(0xFFFFFFFF), // white crest
  ];

  @override
  State<GradientWave> createState() => _GradientWaveState();
}

class _GradientWaveState extends State<GradientWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(_ctrl.value, widget.colors),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  const _WavePainter(this.t, this.colors);

  static const _layers = [
    (amp: 0.080, freq: 1.4, speed: 0.65, yR: 0.18, op: 0.55, ci: 1),
    (amp: 0.070, freq: 1.9, speed: 1.05, yR: 0.24, op: 0.45, ci: 2),
    (amp: 0.060, freq: 2.4, speed: 0.80, yR: 0.29, op: 0.38, ci: 3),
    (amp: 0.050, freq: 2.9, speed: 1.20, yR: 0.33, op: 0.30, ci: 4),
    (amp: 0.040, freq: 3.5, speed: 0.90, yR: 0.37, op: 0.22, ci: 5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // base gradient background
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors[0], colors[1]],
          stops: const [0.0, 1.0],
        ).createShader(Offset.zero & size),
    );

    for (final l in _layers) {
      if (l.ci >= colors.length) continue;
      _drawWave(
        canvas,
        size,
        colors[l.ci].withValues(alpha: l.op),
        l.amp,
        l.freq,
        l.speed,
        l.yR,
      );
    }
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    Color color,
    double amp,
    double freq,
    double speed,
    double yRatio,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final baseY = size.height * yRatio;
    final amplitude = size.height * amp;
    final phase = t * speed * 2 * math.pi;

    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseY + math.sin(phase) * amplitude);

    for (double x = 1; x <= size.width; x += 3) {
      path.lineTo(
        x,
        baseY +
            math.sin((x / size.width) * freq * 2 * math.pi + phase) *
                amplitude,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}
