import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

/// Rasgos de la gotita. Todos son números para poder pasar de una expresión a otra suavemente.
@immutable
class FaceExpression {
  const FaceExpression({
    required this.color,
    this.smile = 0,
    this.mouthOpen = 0,
    this.eyeHappy = 0,
    this.lid = 0,
    this.brow = 0,
    this.browShow = 0,
    this.blush = 0,
    this.sweat = 0,
    this.tear = 0,
    this.sparkle = 0,
    this.bounce = 0,
    this.shiver = 0,
  });

  final Color color;

  /// −1 boca triste … 1 sonrisa amplia.
  final double smile;

  /// 0 boca cerrada … 1 abierta (carcajada o susto).
  final double mouthOpen;

  /// 0 ojos redondos … 1 ojos en arco (^ ^).
  final double eyeHappy;

  /// Párpados caídos (aburrimiento, cansancio).
  final double lid;

  /// −1 cejas de preocupación … 1 cejas de enfado.
  final double brow;
  final double browShow;
  final double blush, sweat, tear, sparkle;

  /// Saltitos de alegría (0–1).
  final double bounce;

  /// Tembleque de nervios (0–1).
  final double shiver;

  static FaceExpression lerp(FaceExpression a, FaceExpression b, double t) => FaceExpression(
    color: Color.lerp(a.color, b.color, t)!,
    smile: lerpDouble(a.smile, b.smile, t)!,
    mouthOpen: lerpDouble(a.mouthOpen, b.mouthOpen, t)!,
    eyeHappy: lerpDouble(a.eyeHappy, b.eyeHappy, t)!,
    lid: lerpDouble(a.lid, b.lid, t)!,
    brow: lerpDouble(a.brow, b.brow, t)!,
    browShow: lerpDouble(a.browShow, b.browShow, t)!,
    blush: lerpDouble(a.blush, b.blush, t)!,
    sweat: lerpDouble(a.sweat, b.sweat, t)!,
    tear: lerpDouble(a.tear, b.tear, t)!,
    sparkle: lerpDouble(a.sparkle, b.sparkle, t)!,
    bounce: lerpDouble(a.bounce, b.bounce, t)!,
    shiver: lerpDouble(a.shiver, b.shiver, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is FaceExpression &&
      other.color == color &&
      other.smile == smile &&
      other.mouthOpen == mouthOpen &&
      other.eyeHappy == eyeHappy &&
      other.lid == lid &&
      other.brow == brow &&
      other.browShow == browShow &&
      other.blush == blush &&
      other.sweat == sweat &&
      other.tear == tear &&
      other.sparkle == sparkle &&
      other.bounce == bounce &&
      other.shiver == shiver;

  @override
  int get hashCode => Object.hash(color, smile, mouthOpen, eyeHappy, lid, brow, browShow, blush, sweat, tear, sparkle, bounce, shiver);
}

/// Gotita animada (estilo kawaii): cambia de expresión con suavidad, respira como gelatina, parpadea,
/// mira a su alrededor y, según el ánimo, da saltitos o tiembla. Con [followPointer] sigue el puntero
/// con los ojos; [MoodFaceState.boing] la hace saltar y soltar corazones o gotitas.
/// Con «reducir movimiento» queda quieta.
class MoodFace extends StatefulWidget {
  const MoodFace({super.key, required this.expression, this.size = 64, this.lively = true, this.followPointer = false, this.semanticLabel});
  final FaceExpression expression;
  final double size;
  final bool lively;
  final bool followPointer;
  final String? semanticLabel;

  @override
  State<MoodFace> createState() => MoodFaceState();
}

class MoodFaceState extends State<MoodFace> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final AnimationController _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);
  late final AnimationController _boing = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late FaceExpression _from = widget.expression;
  Offset _look = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIdle();
  }

  @override
  void didUpdateWidget(MoodFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      _from = FaceExpression.lerp(_from, oldWidget.expression, crEase.transform(_morph.value));
      if (context.reduceMotion) {
        _morph.value = 1;
      } else {
        _morph.forward(from: 0);
      }
    }
    if (oldWidget.lively != widget.lively) _syncIdle();
  }

  void _syncIdle() {
    if (widget.lively && !context.reduceMotion) {
      if (!_idle.isAnimating) _idle.repeat();
    } else {
      _idle.stop();
    }
  }

  /// Saltito con estallido de corazones (o gotitas si está triste), por ejemplo al tocarla.
  void boing() {
    if (!context.reduceMotion) _boing.forward(from: 0);
  }

  @override
  void dispose() {
    _idle.dispose();
    _morph.dispose();
    _boing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget face = RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_idle, _morph, _boing]),
          builder: (context, _) => CustomPaint(
            painter: FacePainter(
              FaceExpression.lerp(_from, widget.expression, crEase.transform(_morph.value)),
              _idle.value,
              look: _look,
              jump: _boing.value,
            ),
          ),
        ),
      ),
    );
    if (widget.followPointer) {
      face = MouseRegion(
        onHover: (e) {
          final half = widget.size / 2;
          final d = (e.localPosition - Offset(half, half)) / (half * 2.5);
          setState(() => _look = Offset(d.dx.clamp(-1.0, 1.0), d.dy.clamp(-1.0, 1.0)));
        },
        onExit: (_) => setState(() => _look = Offset.zero),
        child: face,
      );
    }
    return Semantics(label: widget.semanticLabel, image: widget.semanticLabel != null, excludeSemantics: true, child: face);
  }
}

/// Pinta la gotita en una caja cuadrada. El cuerpo ocupa ~70 % para dejar sitio a saltos y destellos.
class FacePainter extends CustomPainter {
  FacePainter(this.f, this.t, {this.look = Offset.zero, this.jump = 0});
  final FaceExpression f;

  /// Fase del ciclo de reposo (0–1): respiración, parpadeo y detalles.
  final double t;

  /// Hacia dónde mira (−1…1 en cada eje); cero = de frente (y entonces mira a su alrededor sola).
  final Offset look;

  /// Progreso del saltito al tocarla (0–1).
  final double jump;

  static const _ink = Color(0xFF2A0F3A);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.34; // radio de la panza
    final phase = t * math.pi * 2;
    final base = Offset(size.width / 2, size.height * 0.60);

    // Movimiento de cuerpo: respiración gelatinosa, saltitos de alegría, tembleque y salto al tocar
    final breathe = math.sin(phase * 2) * 0.035;
    final hopPhase = (t * 3) % 1; // tres saltitos por ciclo
    final hop = f.bounce * math.max(0.0, math.sin(hopPhase * math.pi)) * r * 0.22;
    final land = f.bounce * (hopPhase < 0.12 ? (1 - hopPhase / 0.12) * 0.10 : 0.0);
    final jumpUp = math.sin(jump * math.pi) * r * 0.55;
    final jumpSquash = jump == 0 ? 0.0 : (jump < 0.15 ? jump / 0.15 * 0.14 : (jump > 0.85 ? (1 - jump) / 0.15 * 0.12 : -0.06));
    final shake = f.shiver * math.sin(phase * 22) * r * 0.035;
    final sx = 1 + breathe + land + jumpSquash;
    final sy = 1 - breathe - land - jumpSquash;
    final sway = math.sin(phase) * 0.05 * (1 - f.shiver * 0.5);

    // Sombra en el suelo: se encoge cuando la gotita sube
    final lift = (hop + jumpUp) / (r * 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, base.dy + r * 1.02),
        width: r * 1.5 * (1 - lift * 0.35),
        height: r * 0.22 * (1 - lift * 0.35),
      ),
      Paint()
        ..color = f.color.withValues(alpha: 0.28 * (1 - lift * 0.5))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );

    canvas.save();
    canvas.translate(base.dx + shake, base.dy - hop - jumpUp);
    // Escala desde la base para que aplaste contra el suelo
    canvas.translate(0, r);
    canvas.scale(sx, sy);
    canvas.translate(0, -r);

    final body = _dropPath(r, sway);
    // Halo suave
    canvas.drawPath(
      body,
      Paint()
        ..color = f.color.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
    );
    // Cuerpo con volumen de agua
    final bounds = Rect.fromCircle(center: Offset(0, -r * 0.2), radius: r * 1.4);
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.1),
          radius: 0.85,
          colors: [Color.lerp(f.color, Colors.white, 0.55)!, f.color, Color.lerp(f.color, Colors.black, 0.22)!],
          stops: const [0, 0.55, 1],
        ).createShader(bounds),
    );
    // Contorno sutil
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..color = Color.lerp(f.color, Colors.black, 0.35)!.withValues(alpha: 0.35),
    );
    // Brillos de gota: una veta curva y un punto
    final streak = Path()
      ..moveTo(-r * 0.55, -r * 0.15)
      ..quadraticBezierTo(-r * 0.62, -r * 0.62, -r * 0.22, -r * 1.05);
    canvas.drawPath(
      streak,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.12
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.drawCircle(Offset(-r * 0.52, r * 0.08), r * 0.06, Paint()..color = Colors.white.withValues(alpha: 0.6));

    _face(canvas, r, phase);
    canvas.restore();

    // Destellos alrededor (radiante)
    if (f.sparkle > 0.05) {
      final star = Paint()..color = Colors.white.withValues(alpha: 0.9 * f.sparkle);
      for (var i = 0; i < 3; i++) {
        final a = phase + i * math.pi * 2 / 3;
        final p = Offset(size.width / 2, base.dy - r * 0.35 - hop - jumpUp) + Offset(math.cos(a) * r * 1.45, math.sin(a) * r * 1.25);
        _star(canvas, p, r * (0.11 + 0.05 * math.sin(phase * 3 + i)) * f.sparkle, star);
      }
    }

    // Estallido al tocarla: corazones si está contenta, gotitas si no
    if (jump > 0 && jump < 1) {
      final happy = f.smile > 0.2;
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + (i - 2.5) * 0.45;
        final dist = r * (0.9 + jump * 1.1);
        final p = Offset(size.width / 2, base.dy - r * 0.6) + Offset(math.cos(a) * dist, math.sin(a) * dist * 0.9);
        final paint = Paint()..color = (happy ? const Color(0xFFFF6FAE) : const Color(0xFF7DD3FC)).withValues(alpha: (1 - jump) * 0.95);
        final k = r * 0.13 * (1 - jump * 0.4);
        if (happy) {
          _heart(canvas, p, k, paint);
        } else {
          canvas.drawPath(_dropPath(k, 0).shift(p), paint);
        }
      }
    }
  }

  /// Silueta de gota: punta arriba (que se mece con [sway]) y panza redonda centrada en el origen.
  Path _dropPath(double r, double sway) {
    final tip = Offset(sway * r * 2.2, -r * 1.75);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(tip.dx + r * 0.25, -r * 1.25, r * 1.0, -r * 0.65, r * 1.0, 0)
      ..cubicTo(r * 1.0, r * 0.58, r * 0.55, r * 1.0, 0, r * 1.0)
      ..cubicTo(-r * 0.55, r * 1.0, -r * 1.0, r * 0.58, -r * 1.0, 0)
      ..cubicTo(-r * 1.0, -r * 0.65, tip.dx - r * 0.25, -r * 1.25, tip.dx, tip.dy)
      ..close();
  }

  void _face(Canvas canvas, double r, double phase) {
    // Mirada: sigue el puntero o, si no hay, mira a su alrededor despacio
    final wander = look == Offset.zero ? Offset(math.sin(phase) * 0.6, math.sin(phase * 0.5) * 0.25) : look;
    final gaze = Offset(wander.dx * r * 0.09, wander.dy * r * 0.06);
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.085;

    // Mejillas
    if (f.blush > 0.01) {
      final blush = Paint()..color = const Color(0xFFFF5C8A).withValues(alpha: 0.5 * f.blush);
      for (final s in [-1, 1]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(s * r * 0.58, r * 0.30), width: r * 0.36, height: r * 0.20), blush);
      }
    }

    // Ojos grandes y brillantes; parpadeo cada ciclo
    final blink = (t > 0.90 && t < 0.96) ? 1 - math.sin((t - 0.90) / 0.06 * math.pi) : 1.0;
    for (final s in [-1, 1]) {
      final eye = Offset(s * r * 0.38, r * 0.02) + gaze;
      final openness = (1 - f.eyeHappy) * blink * (1 - f.lid * 0.5);
      if (openness > 0.1) {
        canvas.drawOval(Rect.fromCenter(center: eye, width: r * 0.30, height: r * 0.40 * openness), Paint()..color = _ink);
        if (openness > 0.45) {
          // Reflejos kawaii: uno grande arriba y otro pequeño abajo
          canvas.drawCircle(eye + Offset(-r * 0.05, -r * 0.08 * openness), r * 0.075, Paint()..color = Colors.white);
          canvas.drawCircle(eye + Offset(r * 0.06, r * 0.08 * openness), r * 0.035, Paint()..color = Colors.white.withValues(alpha: 0.85));
        }
      } else if (f.eyeHappy <= 0.05) {
        canvas.drawLine(eye - Offset(r * 0.12, 0), eye + Offset(r * 0.12, 0), line);
      }
      if (f.eyeHappy > 0.05) {
        final arc = Path()
          ..moveTo(eye.dx - r * 0.14, eye.dy + r * 0.05)
          ..quadraticBezierTo(eye.dx, eye.dy - r * 0.17 * f.eyeHappy, eye.dx + r * 0.14, eye.dy + r * 0.05);
        canvas.drawPath(arc, Paint.from(line)..color = _ink.withValues(alpha: f.eyeHappy.clamp(0.0, 1.0)));
      }
      // Párpado caído (aburrimiento)
      if (f.lid > 0.05 && f.eyeHappy < 0.5) {
        final y = eye.dy - r * 0.20 + r * 0.16 * f.lid;
        canvas.drawLine(Offset(eye.dx - r * 0.17, y), Offset(eye.dx + r * 0.17, y), Paint.from(line)..strokeWidth = r * 0.07);
      }
      // Cejas: preocupación (interior alto) o enfado (interior bajo)
      if (f.browShow > 0.05) {
        final inner = eye + Offset(-s * r * 0.10, -r * 0.32 + f.brow * r * 0.09);
        final outer = eye + Offset(s * r * 0.15, -r * 0.32 - f.brow * r * 0.06);
        canvas.drawLine(inner, outer, Paint.from(line)..color = _ink.withValues(alpha: f.browShow.clamp(0.0, 1.0)));
      }
    }

    // Boquita pequeña, centrada entre los ojos
    final mouthY = r * 0.30 + gaze.dy * 0.5;
    final half = r * (0.13 + 0.05 * f.smile.abs() + 0.06 * f.mouthOpen);
    final curve = f.smile * r * 0.16;
    final cx = gaze.dx * 0.6;
    if (f.mouthOpen > 0.05) {
      final drop = r * 0.24 * f.mouthOpen;
      final mouth = Path()
        ..moveTo(cx - half, mouthY - curve * 0.2)
        ..quadraticBezierTo(cx, mouthY + curve * 0.3 - drop * 0.15, cx + half, mouthY - curve * 0.2)
        ..quadraticBezierTo(cx, mouthY + curve + drop, cx - half, mouthY - curve * 0.2)
        ..close();
      canvas.drawPath(mouth, Paint()..color = _ink);
      canvas.save();
      canvas.clipPath(mouth);
      canvas.drawCircle(Offset(cx, mouthY + curve + drop * 0.9), r * 0.14, Paint()..color = const Color(0xFFFF6B8F));
      canvas.restore();
    } else {
      final mouth = Path()
        ..moveTo(cx - half, mouthY - curve * 0.2)
        ..quadraticBezierTo(cx, mouthY + curve, cx + half, mouthY - curve * 0.2);
      canvas.drawPath(mouth, Paint.from(line)..strokeWidth = r * 0.075);
    }

    // Gota de sudor que resbala por la sien
    if (f.sweat > 0.05) {
      final slide = (t * 2) % 1;
      final p = Offset(r * 0.78, -r * 0.55 + slide * r * 0.35);
      canvas.drawPath(
        _dropPath(r * 0.10, 0).shift(p),
        Paint()..color = const Color(0xFFBAE6FD).withValues(alpha: f.sweat * (1 - slide * 0.6)),
      );
    }

    // Lágrima que cae desde el ojo
    if (f.tear > 0.05) {
      final fall = (t * 1.5) % 1;
      final p = Offset(-r * 0.40, r * 0.20 + fall * r * 0.55);
      canvas.drawPath(_dropPath(r * 0.08, 0).shift(p), Paint()..color = const Color(0xFFBAE6FD).withValues(alpha: f.tear * (1 - fall)));
    }
  }

  void _star(Canvas canvas, Offset p, double k, Paint paint) {
    final path = Path()
      ..moveTo(p.dx, p.dy - k * 1.6)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + k * 1.6, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + k * 1.6)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - k * 1.6, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - k * 1.6);
    canvas.drawPath(path, paint);
  }

  void _heart(Canvas canvas, Offset p, double k, Paint paint) {
    final path = Path()
      ..moveTo(p.dx, p.dy + k)
      ..cubicTo(p.dx - k * 1.6, p.dy - k * 0.2, p.dx - k * 0.7, p.dy - k * 1.4, p.dx, p.dy - k * 0.45)
      ..cubicTo(p.dx + k * 0.7, p.dy - k * 1.4, p.dx + k * 1.6, p.dy - k * 0.2, p.dx, p.dy + k)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(FacePainter old) => old.f != f || old.t != t || old.look != look || old.jump != jump;
}
