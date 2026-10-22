import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small, optically consistent pin for list metadata and swipe actions.
class PinMark extends StatelessWidget {
  final double size;
  final bool filled;

  const PinMark({super.key, this.size = 16, this.filled = true});

  @override
  Widget build(BuildContext context) => Semantics(
        label: filled ? '已置顶' : '置顶',
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _PinPainter(filled)),
        ),
      );
}

class _PinPainter extends CustomPainter {
  final bool filled;
  const _PinPainter(this.filled);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.translate(12, 12);
    canvas.rotate(math.pi / 6);
    canvas.translate(-12, -12);

    final outline = Paint()
      ..color = const Color(0xFFAE7B25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(const Offset(12, 16), const Offset(12, 22), outline);
    final body = Path()
      ..moveTo(9, 6)
      ..lineTo(9, 10)
      ..quadraticBezierTo(9, 12, 6, 14)
      ..quadraticBezierTo(5, 15, 6, 16)
      ..lineTo(18, 16)
      ..quadraticBezierTo(19, 15, 18, 14)
      ..quadraticBezierTo(15, 12, 15, 10)
      ..lineTo(15, 6)
      ..close();
    canvas.drawPath(
        body,
        Paint()
          ..color = filled ? const Color(0xFFF8E2A2) : const Color(0xFFFFFBF1));
    canvas.drawPath(body, outline);
    final cap = RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 3, 10, 4), const Radius.circular(1.8));
    canvas.drawRRect(
        cap,
        Paint()
          ..color = filled ? const Color(0xFFE8B94C) : const Color(0xFFFFFBF1));
    canvas.drawRRect(cap, outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PinPainter oldDelegate) =>
      filled != oldDelegate.filled;
}
