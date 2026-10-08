// مجسم القافلة: جمل مرسوم بمسار متجه داخل شارة كهرمانية.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// شارة القافلة فوق المحطة النشطة.
class CaravanMarker extends StatelessWidget {
  const CaravanMarker({super.key, this.size = 46, this.waiting = false});

  /// القطر.
  final double size;

  /// هل القافلة تنتظر الفجر.
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Semantics(
      label: waiting ? 'القافلة تنتظر الفجر' : 'موضع القافلة',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: palette.amberGradient,
          border: Border.all(color: palette.surface, width: 2.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.amber.withValues(alpha: 0.45),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: CamelGlyphPainter(color: palette.onAccent),
          ),
        ),
      ),
    );
  }
}

/// يرسم صورة الجمل الظلية في مربع.
class CamelGlyphPainter extends CustomPainter {
  const CamelGlyphPainter({required this.color});

  /// لون الجمل.
  final Color color;

  static final Path _camel = Path()
    ..moveTo(4.2, 9.6)
    ..cubicTo(4.2, 8.1, 5.3, 7, 6.7, 7)
    ..lineTo(8.3, 7)
    ..cubicTo(9.3, 7, 9.9, 7.9, 9.7, 8.9)
    ..lineTo(9.1, 12.3)
    ..cubicTo(10.7, 11.9, 11.6, 9.7, 13.3, 8.2)
    ..cubicTo(15.5, 6.3, 18.7, 6.4, 20.4, 8.6)
    ..cubicTo(21.4, 9.9, 22.1, 11, 23.8, 11.4)
    ..cubicTo(26, 11.9, 27.5, 13.6, 27.7, 15.8)
    ..lineTo(27.9, 17.4)
    ..cubicTo(28, 18.4, 27.4, 19.3, 26.5, 19.6)
    ..lineTo(26.1, 19.7)
    ..lineTo(26.5, 27.5)
    ..lineTo(24.7, 27.5)
    ..lineTo(23.6, 20.6)
    ..lineTo(22.5, 20.6)
    ..lineTo(22.8, 27.5)
    ..lineTo(21, 27.5)
    ..lineTo(19.9, 20.7)
    ..lineTo(14.5, 20.7)
    ..lineTo(13.6, 27.5)
    ..lineTo(11.8, 27.5)
    ..lineTo(11.9, 20.4)
    ..lineTo(10.8, 20)
    ..lineTo(9.9, 27.5)
    ..lineTo(8.2, 27.5)
    ..lineTo(8.5, 18.7)
    ..cubicTo(7.7, 17.3, 7.3, 15.5, 7.2, 13.5)
    ..lineTo(7.1, 11.9)
    ..lineTo(5.4, 11.9)
    ..cubicTo(4.7, 11.9, 4.2, 11.3, 4.2, 10.6)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    const double glyphBox = 32;
    final double scale = size.shortestSide * 0.68 / glyphBox;
    final double dx = (size.width - glyphBox * scale) / 2;
    final double dy = (size.height - glyphBox * scale) / 2 + size.height * 0.02;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    canvas.drawPath(
      _camel,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CamelGlyphPainter oldDelegate) => oldDelegate.color != color;
}
