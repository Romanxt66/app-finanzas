import 'package:flutter/material.dart';

/// Logotipo de Alvea: una «A» con una línea de tendencia que sube hasta un punto brillante.
/// Se dibuja en vectorial a partir de `brand/alvea-icon.svg` (caja de 108 × 108).
class AlveaLogo extends StatelessWidget {
  const AlveaLogo({super.key, this.size = 32, this.background = true});
  final double size;

  /// Con el cuadrado redondeado de fondo; sin él queda solo el símbolo.
  final bool background;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Alvea',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: AlveaLogoPainter(background: background)),
    ),
  );
}

class AlveaLogoPainter extends CustomPainter {
  const AlveaLogoPainter({this.background = true});
  final bool background;

  static const violet = Color(0xFF9B3BEA);
  static const glow = Color(0xFFB54DFF);
  static const line = Color(0xFFC35BFF);
  static const spark = Color(0xFFF3DDFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);

    if (background) {
      final box = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 108, 108), const Radius.circular(24));
      canvas.drawRRect(
        box,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -0.4),
            radius: 0.8,
            colors: [Color(0xFF2A0F4A), Color(0xFF140826), Color(0xFF0A0414)],
            stops: [0, 0.6, 1],
          ).createShader(const Rect.fromLTWH(0, 0, 108, 108)),
      );
      canvas.drawRRect(
        box.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = glow.withValues(alpha: 0.35),
      );
    }

    canvas.translate(-3, 1);
    Paint stroke(double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // «A»: borde violeta, relleno oscuro en degradado y sombra suave debajo
    final a = Path()
      ..moveTo(36, 78)
      ..lineTo(54, 32)
      ..lineTo(72, 78);
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(
      a,
      stroke(11.5)
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
    canvas.drawPath(a, stroke(11.5)..color = violet);
    canvas.drawPath(
      a,
      stroke(8)
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B1250), Color(0xFF0E0520)],
        ).createShader(const Rect.fromLTRB(36, 32, 72, 78)),
    );

    // Tendencia que sube hasta el punto, con halo luminoso
    final trend = Path()
      ..moveTo(40, 64)
      ..lineTo(51, 57)
      ..lineTo(58, 61)
      ..lineTo(74, 48);
    final halo = Paint()
      ..color = glow.withValues(alpha: 0.95)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
    for (var i = 0; i < 2; i++) {
      canvas.drawPath(
        trend,
        stroke(7)
          ..color = halo.color
          ..maskFilter = halo.maskFilter,
      );
      canvas.drawCircle(const Offset(78, 45), 5.5, halo);
    }
    canvas.drawPath(trend, stroke(7)..color = line);
    canvas.drawCircle(const Offset(78, 45), 5.5, Paint()..color = line);
    canvas.drawCircle(const Offset(78, 45), 2.2, Paint()..color = spark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AlveaLogoPainter old) => old.background != background;
}
