import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

String formatRp(int amount) {
  final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  return formatter.format(amount);
}

String formatRpShort(int amount) {
  if (amount >= 1000000) return 'Rp ${(amount / 1000000).toStringAsFixed(1)}jt';
  if (amount >= 1000) return 'Rp ${(amount / 1000).toStringAsFixed(0)}k';
  return formatRp(amount);
}

class UGTAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Color bgColor;

  const UGTAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.bgColor = AppColors.surface,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1)),
          ),
          child: Row(
            children: [
              if (onBack != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: const Icon(Icons.chevron_left, size: 24, color: AppColors.text),
                    ),
                  ),
                ),
              if (onBack != null) const SizedBox(width: 4),
              Expanded(
                child: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

class UGTButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color bgColor;
  final Color textColor;
  final Widget? icon;
  final double height;
  final double fontSize;
  final double borderRadius;
  final List<BoxShadow>? shadows;

  const UGTButton({
    super.key,
    required this.label,
    required this.onTap,
    this.bgColor = AppColors.primary,
    this.textColor = Colors.white,
    this.icon,
    this.height = 50,
    this.fontSize = 14,
    this.borderRadius = 15,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: shadows,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: fontSize, fontWeight: FontWeight.w600, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UGTCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color color;
  final List<BoxShadow>? shadows;

  const UGTCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 18,
    this.color = AppColors.surface,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  final String text;
  final double size;
  final double fontSize;
  final double borderRadius;
  final Color bgColor;
  final Color textColor;

  const InitialsAvatar({
    super.key,
    required this.text,
    this.size = 44,
    this.fontSize = 14,
    this.borderRadius = 14,
    this.bgColor = AppColors.grayLight,
    this.textColor = AppColors.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class ToastWidget extends StatelessWidget {
  final String message;

  const ToastWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 20,
      right: 20,
      bottom: 96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 13),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dashW = 6.0;
        const space = 4.0;
        final count = (constraints.maxWidth / (dashW + space)).floor();
        return Row(
          children: List.generate(count, (_) => Container(
            width: dashW,
            height: 1,
            color: AppColors.border,
            margin: const EdgeInsets.only(right: space),
          )),
        );
      },
    );
  }
}

class SalesChartPainter extends CustomPainter {
  final List<int> data;

  const SalesChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.fold(0, (m, v) => v > m ? v : m);
    final n = data.length;
    final slotW = size.width / n;
    final barW  = (slotW * 0.52).clamp(4.0, 28.0);

    final emptyPaint = Paint()
      ..color = const Color(0xFFDCFCE7)
      ..style = PaintingStyle.fill;
    final barPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final dotFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Min bar height so zero days still show a tiny stub
    const minH = 3.0;
    final usableH = size.height * 0.88;

    int maxIdx = 0;
    for (int i = 1; i < n; i++) {
      if (data[i] > data[maxIdx]) maxIdx = i;
    }

    for (int i = 0; i < n; i++) {
      final val = data[i];
      final h = maxVal > 0
          ? minH + (val / maxVal) * (usableH - minH)
          : minH;
      final x = slotW * i + (slotW - barW) / 2;
      final y = size.height - h;
      final isMax = i == maxIdx && maxVal > 0;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barW, h),
          topLeft:  const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        isMax ? barPaint : emptyPaint,
      );

      if (isMax) {
        final cx = x + barW / 2;
        canvas.drawCircle(Offset(cx, y - 5), 4.0, dotFillPaint);
        canvas.drawCircle(Offset(cx, y - 5), 4.0, dotBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(SalesChartPainter old) => old.data != data;
}

// Grid lines
class GridLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 1;
    for (final y in [0.19, 0.48, 0.77]) {
      canvas.drawLine(Offset(0, size.height * y), Offset(size.width, size.height * y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({super.key, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.grayLight,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class QtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback onInc;
  final VoidCallback onDec;

  const QtyControl({super.key, required this.qty, required this.onInc, required this.onDec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDec,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x24000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: const Icon(Icons.remove, size: 13, color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          GestureDetector(
            onTap: onInc,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
