import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _processing = false;
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Expect format: ugtmart-qr:<token>
    if (!raw.startsWith('ugtmart-qr:')) return;
    final token = raw.substring('ugtmart-qr:'.length).trim();
    if (token.isEmpty) return;

    final username = context.read<AppProvider>().kasirUsername;
    setState(() => _processing = true);
    await _ctrl.stop();

    try {
      final res = await Supabase.instance.client
          .rpc('scan_qr_token', params: {'p_token': token, 'p_username': username});

      if (!mounted) return;

      // scan_qr_token returns: {'ok': true/false, 'pesan': '...'}
      final ok = res is Map && res['ok'] == true;
      final pesan = res is Map ? (res['pesan'] as String? ?? '') : '';

      if (ok) {
        setState(() => _done = true);
        _showResult(true, 'Login web panel berhasil!\nSilakan lanjutkan di browser.');
      } else if (pesan.contains('expired')) {
        _retryAfterFailure();
        _showResult(false, 'QR Code sudah kedaluwarsa.\nMuat ulang QR di browser.');
      } else {
        _retryAfterFailure();
        _showResult(false, pesan.isNotEmpty ? pesan : 'QR Code tidak valid atau sudah digunakan.');
      }
    } catch (e) {
      if (!mounted) return;
      _retryAfterFailure();
      _showResult(false, 'Terjadi kesalahan: ${e.toString()}');
    }
  }

  void _retryAfterFailure() {
    setState(() => _processing = false);
    _ctrl.start();
  }

  void _showResult(bool success, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: success ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                size: 36,
                color: success ? AppColors.primary : AppColors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Berhasil!' : 'Gagal',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textDim, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? AppColors.primary : AppColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  if (success) Navigator.of(context).pop(); // back to profile
                },
                child: Text('Tutup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),
          // Overlay with cutout
          CustomPaint(
            painter: _ScanOverlayPainter(),
            child: const SizedBox.expand(),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Scan QR Login Web Panel',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: ValueListenableBuilder(
                        valueListenable: _ctrl,
                        builder: (_, state, __) {
                          final torchOn = state.torchState == TorchState.on;
                          return Icon(
                            torchOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                          );
                        },
                      ),
                      onPressed: _ctrl.toggleTorch,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_processing)
                      const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    else
                      Text(
                        'Arahkan kamera ke QR Code\nyang tampil di browser web panel',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.5),
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

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cutSize = 240.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 40;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: cutSize, height: cutSize);

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    // Darken outside cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      ),
      paint,
    );

    // Corner brackets
    const bLen = 24.0;
    const bWidth = 3.5;
    const bRadius = 6.0;
    final bracketPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = bWidth
      ..strokeCap = StrokeCap.round;

    final corners = [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ];

    for (final (corner, dx, dy) in corners) {
      final path = Path();
      path.moveTo(corner.dx + dx * bRadius, corner.dy);
      path.lineTo(corner.dx + dx * bLen, corner.dy);
      path.moveTo(corner.dx, corner.dy + dy * bRadius);
      path.lineTo(corner.dx, corner.dy + dy * bLen);
      canvas.drawPath(path, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
