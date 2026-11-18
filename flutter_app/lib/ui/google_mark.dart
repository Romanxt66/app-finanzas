import 'dart:math' as math;

import 'package:flutter/material.dart';

/// La «G» de Google con sus cuatro colores sobre un círculo blanco, como pide su guía de marca para
/// los botones de inicio de sesión. Vectorial: se ve nítida a cualquier tamaño y sin assets.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: CustomPaint(size: Size.square(size * 0.62), painter: const GoogleGPainter()),
    ),
  );
}

class GoogleGPainter extends CustomPainter {
  const GoogleGPainter();

  static const blue = Color(0xFF4285F4);
  static const green = Color(0xFF34A853);
  static const yellow = Color(0xFFFBBC05);
  static const red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final w = s * 0.2; // grosor del trazo
    final r = (s - w) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    Paint arc(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = color;
    double deg(double d) => d * math.pi / 180;
    // Ángulos en el sentido de las agujas del reloj desde las 3: la abertura queda arriba a la derecha
    canvas.drawArc(rect, deg(-140), deg(100), false, arc(red));
    canvas.drawArc(rect, deg(140), deg(80), false, arc(yellow));
    canvas.drawArc(rect, deg(42), deg(98), false, arc(green));
    canvas.drawArc(rect, deg(0), deg(44), false, arc(blue));
    // Barra horizontal de la G
    canvas.drawRect(Rect.fromLTRB(center.dx, center.dy - w / 2, center.dx + r + w / 2, center.dy + w / 2), Paint()..color = blue);
  }

  @override
  bool shouldRepaint(GoogleGPainter oldDelegate) => false;
}
