import 'package:flutter/material.dart';

/// Logotipo de Alvea: la «A» de trazo redondeado con un punto, sobre el cuadrado oscuro
/// (`brand/alvea-icon.svg`). Se dibuja en vectorial: nítido a cualquier tamaño y sin esperar a un asset.
class AlveaLogo extends StatelessWidget {
  const AlveaLogo({super.key, this.size = 32, this.background = true, this.ink});
  final double size;

  /// Con el cuadrado redondeado de fondo; sin él queda solo el símbolo (para poner sobre algo oscuro).
  final bool background;

  /// Color liso del símbolo; por defecto, blanco con un degradado plateado.
  final Color? ink;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Alvea',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: AlveaLogoPainter(background: background, ink: ink),
      ),
    ),
  );
}

/// Dibuja la marca en una caja de 108 × 108 (la del icono adaptativo de Android), escalada al tamaño.
class AlveaLogoPainter extends CustomPainter {
  const AlveaLogoPainter({this.background = true, this.ink});
  final bool background;
  final Color? ink;

  static const legs = [Offset(35, 77), Offset(54, 31), Offset(73, 77)];
  static const dot = Offset(54, 63.2);
  static const dotRadius = 5.7;
  static const strokeWidth = 9.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);

    if (background) {
      const box = Rect.fromLTWH(0, 0, 108, 108);
      final rrect = RRect.fromRectAndRadius(box, const Radius.circular(24));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.44, -0.64),
            radius: 1.0,
            colors: [Color(0xFF2C2C31), Color(0xFF121214), Color(0xFF050506)],
            stops: [0, 0.55, 1],
          ).createShader(box),
      );
      canvas.drawRRect(
        rrect.deflate(0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.24), Colors.white.withValues(alpha: 0.04), Colors.white.withValues(alpha: 0.10)],
            stops: const [0, 0.5, 1],
          ).createShader(box),
      );
      // El símbolo un poco más grande dentro del cuadrado, como en el icono de la app
      canvas.translate(54, 54);
      canvas.scale(1.08);
      canvas.translate(-54, -54);
    }

    Paint base() {
      final p = Paint()..isAntiAlias = true;
      if (ink != null) return p..color = ink!;
      return p
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFC8C8CE)],
        ).createShader(const Rect.fromLTRB(0, 31, 108, 81));
    }

    final a = Path()
      ..moveTo(legs[0].dx, legs[0].dy)
      ..lineTo(legs[1].dx, legs[1].dy)
      ..lineTo(legs[2].dx, legs[2].dy);
    canvas.drawPath(
      a,
      base()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(dot, dotRadius, base());
    canvas.restore();
  }

  @override
  bool shouldRepaint(AlveaLogoPainter old) => old.background != background || old.ink != ink;
}
