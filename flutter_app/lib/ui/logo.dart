import 'package:flutter/material.dart';

/// Logotipo de Alvea: la «A» plateada con la línea de tendencia sobre el mapa y las barras
/// (`assets/brand/logo.webp`). [AlveaLogoPainter] queda como versión vectorial para dibujar sin assets.
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
      child: ClipRRect(
        // Sin fondo (p. ej. dentro de la intro, que ya pone su propio cuadrado) apenas se redondea
        borderRadius: BorderRadius.circular(size * (background ? 0.24 : 0.16)),
        child: Image.asset(
          'assets/brand/logo.webp',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          // Mientras carga (o si falla), el símbolo vectorial
          errorBuilder: (_, _, _) => CustomPaint(painter: AlveaLogoPainter(background: background)),
          frameBuilder: (context, child, frame, sync) =>
              frame == null && !sync ? CustomPaint(painter: AlveaLogoPainter(background: background)) : child,
        ),
      ),
    ),
  );
}

class AlveaLogoPainter extends CustomPainter {
  const AlveaLogoPainter({this.background = true});
  final bool background;

  static const violet = Color(0xFF5C5C5C);
  static const glow = Color(0xFF707070);
  static const line = Color(0xFF7D7D7D);
  static const spark = Color(0xFFE4E4E4);

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
            colors: [Color(0xFF191919), Color(0xFF0D0D0D), Color(0xFF060606)],
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
          colors: [Color(0xFF1C1C1C), Color(0xFF090909)],
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
