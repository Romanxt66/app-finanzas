import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Haz de fibras de luz que convergen en un foco y se abren en abanico, con polvo luminoso
/// y una retícula de puntos tenue (estilo «Relay»). Solo decorativo: no recibe toques.
/// Es estático para no costar rendimiento; solo el foco late despacio en pantallas anchas.
class RibbonField extends StatefulWidget {
  const RibbonField({super.key});

  @override
  State<RibbonField> createState() => _RibbonFieldState();
}

class _RibbonFieldState extends State<RibbonField> {
  // El haz se pinta una sola vez (queda en caché); solo el brillo del foco «respira»,
  // con pocos pasos por segundo para no recalcular toda la pantalla en cada fotograma.
  static const _step = Duration(milliseconds: 250);
  static const _steps = 40; // ciclo de 10 s
  final ValueNotifier<int> _tick = ValueNotifier(0);
  Timer? _timer;

  void _sync(bool animate) {
    if (animate && _timer == null) {
      _timer = Timer.periodic(_step, (_) => _tick.value = (_tick.value + 1) % _steps);
    } else if (!animate && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colors = ribbonColors(c);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          // En pantallas estrechas el fondo queda totalmente quieto
          _sync(!context.reduceMotion && box.maxWidth >= 640);
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: CustomPaint(painter: _RibbonPainter(colors, c.isDark))),
              RepaintBoundary(child: CustomPaint(painter: _FocusGlow(_tick, _steps, colors[1], c.isDark))),
            ],
          );
        },
      ),
    );
  }
}

/// Brillo del foco, aparte del haz para repintar solo esta capa.
class _FocusGlow extends CustomPainter {
  _FocusGlow(this.tick, this.steps, this.color, this.dark) : super(repaint: tick);
  final ValueListenable<int> tick;
  final int steps;
  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final k = 0.8 + 0.2 * math.sin(tick.value / steps * math.pi * 2);
    final focus = _spine(0.55, size);
    final r = math.min(size.width, size.height) * 0.16;
    canvas.drawCircle(
      focus,
      r,
      Paint()
        ..blendMode = dark ? BlendMode.plus : BlendMode.srcOver
        ..shader = ui.Gradient.radial(
          focus,
          r,
          [
            Colors.white.withValues(alpha: dark ? 0.32 * k : 0.0),
            color.withValues(alpha: (dark ? 0.22 : 0.10) * k),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.25, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(_FocusGlow old) => old.color != color || old.dark != dark || old.tick != tick;
}

/// Curva central del haz: entra por la derecha, baja al foco y vuelve a abrirse.
Offset _spine(double u, Size s) {
  // En pantallas estrechas el haz se pega al borde derecho para no cruzar los titulares
  final narrow = s.width < 640;
  final p0 = Offset(s.width * (narrow ? 1.25 : 1.08), s.height * -0.08);
  final p1 = Offset(s.width * (narrow ? 1.02 : 0.72), s.height * (narrow ? 0.16 : 0.10));
  final p2 = Offset(s.width * (narrow ? 0.80 : 0.32), s.height * (narrow ? 0.48 : 0.40));
  final p3 = Offset(s.width * (narrow ? 1.05 : 0.46), s.height * 1.05);
  final v = 1 - u;
  return p0 * (v * v * v) + p1 * (3 * v * v * u) + p2 * (3 * v * u * u) + p3 * (u * u * u);
}

/// Colores de las fibras: fucsias de la paleta, un violeta de apoyo y algún azul frío.
List<Color> ribbonColors(CrPalette c) => c.isDark
    ? [c.brand, c.focus, c.chart4, const Color(0xFF93C5FD), c.brand]
    : [c.brandFill, c.focus, c.chart4, const Color(0xFF3B82F6), c.brandFill2];

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.colors, this.dark);
  final List<Color> colors;
  final bool dark;

  static const _strands = 30;
  static const _segments = 40;
  static const _dust = 50;

  // Semillas fijas: el dibujo es estable entre repintados y entre sesiones.
  static final _rand = math.Random(7);
  static final List<double> _phase = List.generate(_strands, (_) => _rand.nextDouble() * math.pi * 2);
  static final List<double> _width = List.generate(_strands, (_) => 0.6 + _rand.nextDouble() * 0.9);
  static final List<double> _alpha = List.generate(_strands, (_) => 0.25 + _rand.nextDouble() * 0.45);
  static final List<int> _tone = List.generate(_strands, (i) => _rand.nextDouble() < 0.14 ? 3 : (i % 3 == 0 ? 2 : (i % 2)));
  static final List<Offset> _dustSeed = List.generate(_dust, (_) => Offset(_rand.nextDouble(), _rand.nextDouble()));
  static final List<double> _dustSize = List.generate(_dust, (_) => 0.6 + _rand.nextDouble() * 1.8);

  /// Apertura del abanico: estrecha en el foco (u ≈ 0,55), ancha en los extremos.
  double _spread(double u, Size s) {
    final d = (u - 0.55).abs() / 0.55;
    return math.min(s.width, s.height) * (0.015 + 0.30 * d * d);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _dots(canvas, size);
    if (size.width < 640) {
      // Más tenue en móvil: el contenido ocupa todo el ancho
      canvas.saveLayer(Offset.zero & size, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.6));
      _paintRibbon(canvas, size);
      canvas.restore();
    } else {
      _paintRibbon(canvas, size);
    }
  }

  void _paintRibbon(Canvas canvas, Size size) {
    final glowBlend = dark ? BlendMode.plus : BlendMode.srcOver;
    final spine = [for (var j = 0; j <= _segments; j++) _spine(j / _segments, size)];

    // Halo amplio bajo el haz: trazos anchos y translúcidos en lugar de un desenfoque
    final halo = Path()..addPolygon(spine, false);
    final base = math.min(size.width, size.height);
    for (final (w, a) in [(0.16, 0.035), (0.10, 0.05), (0.05, 0.06)]) {
      canvas.drawPath(
        halo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = base * w
          ..strokeCap = StrokeCap.round
          ..color = colors[0].withValues(alpha: a * (dark ? 1 : 0.5))
          ..blendMode = glowBlend,
      );
    }

    // Normales de la curva, calculadas una vez para todas las fibras
    final normals = <Offset>[
      for (var j = 0; j <= _segments; j++)
        () {
          final t = spine[math.min(_segments, j + 1)] - spine[math.max(0, j - 1)];
          final len = t.distance == 0 ? 1.0 : t.distance;
          return Offset(-t.dy / len, t.dx / len);
        }(),
    ];
    final shaderFrom = spine.first, shaderTo = spine.last;

    // Fibras
    for (var i = 0; i < _strands; i++) {
      final lane = i / (_strands - 1) - 0.5;
      final pts = <Offset>[];
      for (var j = 0; j <= _segments; j++) {
        final u = j / _segments;
        final wobble = math.sin(u * 6.0 + _phase[i]) * 0.18 + math.sin(u * 13.0 + _phase[i]) * 0.06;
        pts.add(spine[j] + normals[j] * (_spread(u, size) * (lane * 2 + wobble)));
      }
      final path = Path()..addPolygon(pts, false);
      // Una de cada seis fibras es «núcleo»: más gruesa, casi blanca y con brillo propio
      final core = i % 6 == 3;
      final tint = colors[_tone[i] % colors.length];
      final color = core ? Color.lerp(tint, Colors.white, dark ? 0.45 : 0.1)! : tint;
      final a = (core ? 0.85 : _alpha[i]) * (dark ? 1 : 0.55);
      if (core) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..blendMode = glowBlend
            ..color = tint.withValues(alpha: dark ? 0.10 : 0.05),
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
            shaderFrom,
            shaderTo,
            [color.withValues(alpha: 0), color.withValues(alpha: a), color.withValues(alpha: a * 0.9), color.withValues(alpha: 0)],
            const [0.0, 0.35, 0.75, 1.0],
          ),
      );
    }

    // Polvo luminoso repartido a lo largo del haz
    for (var k = 0; k < _dust; k++) {
      final seed = _dustSeed[k];
      final u = seed.dx;
      final p0 = _spine(u, size);
      final side = (seed.dy - 0.5) * 2;
      final p = p0 + Offset(side * _spread(u, size) * 1.4, side * _spread(u, size) * 0.6);
      final twinkle = 0.5 + 0.5 * math.sin(k * 1.7);
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
  bool shouldRepaint(_RibbonPainter old) => old.dark != dark || !listEquals(old.colors, colors);
}
