import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The same warm gold fill and fine outline as the pinned-note marker.
class StarMark extends StatelessWidget {
  final double size;

  const StarMark({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) => Semantics(
        label: '已收藏',
        child: SizedBox.square(
          dimension: size,
          child: const CustomPaint(painter: _StarPainter()),
        ),
      );
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final points = List.generate(10, (index) {
      final angle = -math.pi / 2 + index * math.pi / 5;
      final radius = index.isEven ? 9.5 : 4.8;
      return Offset(
          12 + math.cos(angle) * radius, 12 + math.sin(angle) * radius);
    });
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final incoming = Offset.lerp(point, points[(i + 9) % 10], 0.12)!;
      final outgoing = Offset.lerp(point, points[(i + 1) % 10], 0.12)!;
      if (i == 0) {
        path.moveTo(incoming.dx, incoming.dy);
      } else {
        path.lineTo(incoming.dx, incoming.dy);
      }
      path.quadraticBezierTo(point.dx, point.dy, outgoing.dx, outgoing.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFF8E2A2));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFAE7B25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => false;
}
