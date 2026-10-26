import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Haz de fibras de luz que convergen en un foco y se abren en abanico, con polvo luminoso
/// y una retícula de puntos tenue (estilo «Relay»). Solo decorativo: no recibe toques.
class RibbonField extends StatefulWidget {
  const RibbonField({super.key});

  @override
  State<RibbonField> createState() => _RibbonFieldState();
}

class _RibbonFieldState extends State<RibbonField> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 48));
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = context.reduceMotion;
    if (reduce && _running) {
      _t.stop();
      _running = false;
    } else if (!reduce && !_running) {
      _t.repeat();
      _running = true;
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _RibbonPainter(_t, ribbonColors(c), c.isDark), size: Size.infinite),
      ),
    );
  }
}

/// Colores de las fibras: fucsias de la paleta, un violeta de apoyo y algún azul frío.
List<Color> ribbonColors(CrPalette c) => c.isDark
    ? [c.brand, c.focus, c.chart4, const Color(0xFF93C5FD), c.brand]
    : [c.brandFill, c.focus, c.chart4, const Color(0xFF3B82F6), c.brandFill2];

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.anim, this.colors, this.dark) : super(repaint: anim);
  final Animation<double> anim;
  final List<Color> colors;
  final bool dark;

  static const _strands = 54;
  static const _segments = 48;
  static const _dust = 70;

  // Semillas fijas: el dibujo es estable entre fotogramas y entre sesiones.
  static final _rand = math.Random(7);
  static final List<double> _phase = List.generate(_strands, (_) => _rand.nextDouble() * math.pi * 2);
  static final List<double> _width = List.generate(_strands, (_) => 0.5 + _rand.nextDouble() * 0.9);
  static final List<double> _alpha = List.generate(_strands, (_) => 0.22 + _rand.nextDouble() * 0.45);
  static final List<int> _tone = List.generate(_strands, (i) => _rand.nextDouble() < 0.14 ? 3 : (i % 3 == 0 ? 2 : (i % 2)));
  static final List<Offset> _dustSeed = List.generate(_dust, (_) => Offset(_rand.nextDouble(), _rand.nextDouble()));
  static final List<double> _dustSize = List.generate(_dust, (_) => 0.6 + _rand.nextDouble() * 1.8);

  /// Curva central del haz: entra por la derecha, baja al foco y vuelve a abrirse.
  Offset _spine(double u, Size s, double t) {
    // En pantallas estrechas el haz se pega al borde derecho para no cruzar los titulares
    final narrow = s.width < 640;
    final p0 = Offset(s.width * (narrow ? 1.25 : 1.08), s.height * -0.08);
    final p1 = Offset(s.width * ((narrow ? 1.02 : 0.72) + 0.02 * math.sin(t)), s.height * (narrow ? 0.16 : 0.10));
    final p2 = Offset(s.width * ((narrow ? 0.78 : 0.30) + 0.02 * math.cos(t * 0.8)), s.height * (narrow ? 0.48 : 0.40));
    final p3 = Offset(s.width * (narrow ? 1.05 : 0.46), s.height * 1.05);
    final v = 1 - u;
    return p0 * (v * v * v) + p1 * (3 * v * v * u) + p2 * (3 * v * u * u) + p3 * (u * u * u);
  }

  /// Apertura del abanico: estrecha en el foco (u ≈ 0,55), ancha en los extremos.
  double _spread(double u, Size s) {
    final d = (u - 0.55).abs() / 0.55;
    return math.min(s.width, s.height) * (0.015 + 0.30 * d * d);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value * math.pi * 2;
    _dots(canvas, size);
    if (size.width < 640) {
      // Más tenue en móvil: el contenido ocupa todo el ancho
      canvas.saveLayer(Offset.zero & size, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.6));
      _paintRibbon(canvas, size, t);
      canvas.restore();
    } else {
      _paintRibbon(canvas, size, t);
    }
  }

  void _paintRibbon(Canvas canvas, Size size, double t) {
    final glowBlend = dark ? BlendMode.plus : BlendMode.srcOver;

    // Halo amplio y difuso bajo el haz
    final halo = Path();
    for (var j = 0; j <= _segments; j++) {
      final p = _spine(j / _segments, size, t);
      j == 0 ? halo.moveTo(p.dx, p.dy) : halo.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      halo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.min(size.width, size.height) * 0.10
        ..color = colors[0].withValues(alpha: dark ? 0.15 : 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
        ..blendMode = glowBlend,
    );

    // Fibras
    for (var i = 0; i < _strands; i++) {
      final lane = i / (_strands - 1) - 0.5;
      final path = Path();
      for (var j = 0; j <= _segments; j++) {
        final u = j / _segments;
        final base = _spine(u, size, t);
        final ahead = _spine(math.min(1, u + 0.01), size, t);
        final behind = _spine(math.max(0, u - 0.01), size, t);
        final tangent = ahead - behind;
        final len = tangent.distance == 0 ? 1.0 : tangent.distance;
        final normal = Offset(-tangent.dy / len, tangent.dx / len);
        final wobble = math.sin(u * 6.0 + _phase[i] + t * 1.0) * 0.18 + math.sin(u * 13.0 - t * 1.6 + _phase[i]) * 0.06;
        final offset = _spread(u, size) * (lane * 2 + wobble);
        final p = base + normal * offset;
        j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      // Una de cada nueve fibras es «núcleo»: más gruesa, casi blanca y con brillo propio
      final core = i % 9 == 4;
      final tint = colors[_tone[i] % colors.length];
      final color = core ? Color.lerp(tint, Colors.white, dark ? 0.45 : 0.1)! : tint;
      final a = (core ? 0.85 : _alpha[i]) * (dark ? 1 : 0.55);
      if (core) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..blendMode = glowBlend
            ..color = tint.withValues(alpha: dark ? 0.16 : 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = core ? 1.7 : _width[i]
          ..strokeCap = StrokeCap.round
          ..blendMode = glowBlend
          ..shader = ui.Gradient.linear(
            _spine(0, size, t),
            _spine(1, size, t),
            [color.withValues(alpha: 0), color.withValues(alpha: a), color.withValues(alpha: a * 0.9), color.withValues(alpha: 0)],
            const [0.0, 0.35, 0.75, 1.0],
          ),
      );
    }

    // Foco brillante donde convergen las fibras
    final focus = _spine(0.55, size, t);
    final r = math.min(size.width, size.height) * 0.16;
    canvas.drawCircle(
      focus,
      r,
      Paint()
        ..blendMode = glowBlend
        ..shader = ui.Gradient.radial(
          focus,
          r,
          [
            Colors.white.withValues(alpha: dark ? 0.32 : 0.0),
            colors[1].withValues(alpha: dark ? 0.22 : 0.10),
            colors[1].withValues(alpha: 0),
          ],
          const [0.0, 0.25, 1.0],
        ),
    );

    // Polvo luminoso que deriva a lo largo del haz
    for (var k = 0; k < _dust; k++) {
      final seed = _dustSeed[k];
      final u = (seed.dx + anim.value * (0.35 + seed.dy * 0.4)) % 1.0;
      final base = _spine(u, size, t);
      final side = (seed.dy - 0.5) * 2;
      final p = base + Offset(side * _spread(u, size) * 1.4, side * _spread(u, size) * 0.6);
      final twinkle = 0.5 + 0.5 * math.sin(t * 3 + k);
      canvas.drawCircle(
        p,
        _dustSize[k],
        Paint()
          ..blendMode = glowBlend
          ..color = colors[k % 2].withValues(alpha: (dark ? 0.55 : 0.25) * twinkle * (1 - (u - 0.55).abs())),
      );
    }
  }

  void _dots(Canvas canvas, Size size) {
    const gap = 28.0;
    final pts = <Offset>[];
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        pts.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      pts,
      Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = (dark ? Colors.white : const Color(0xFF16131F)).withValues(alpha: dark ? 0.045 : 0.05),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.dark != dark || old.colors != colors;
}
