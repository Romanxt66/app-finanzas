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

/// Gotita de malvavisco animada (estilo kawaii): cambia de expresión con suavidad, respira como gelatina, parpadea,
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
    final r = size.shortestSide * 0.33; // radio de la panza
    final phase = t * math.pi * 2;
    final base = Offset(size.width / 2, size.height * 0.60);
    // Tonos de malvavisco: el color del ánimo aclarado hacia crema
    final soft = Color.lerp(f.color, const Color(0xFFFFF7FB), 0.38)!;
    final deep = Color.lerp(f.color, const Color(0xFF6B2E7A), 0.22)!;

    // Movimiento de cuerpo: respiración blandita, saltitos de alegría, tembleque y salto al tocar
    final breathe = math.sin(phase * 2) * 0.04;
    final hopPhase = (t * 3) % 1; // tres saltitos por ciclo
    final hop = f.bounce * math.max(0.0, math.sin(hopPhase * math.pi)) * r * 0.24;
    final land = f.bounce * (hopPhase < 0.14 ? (1 - hopPhase / 0.14) * 0.13 : 0.0);
    final jumpUp = math.sin(jump * math.pi) * r * 0.6;
    final jumpSquash = jump == 0 ? 0.0 : (jump < 0.15 ? jump / 0.15 * 0.16 : (jump > 0.85 ? (1 - jump) / 0.15 * 0.14 : -0.07));
    final shake = f.shiver * math.sin(phase * 22) * r * 0.035;
    final sx = 1 + breathe + land + jumpSquash;
    final sy = 1 - breathe - land - jumpSquash;
    final sway = math.sin(phase) * 0.06 * (1 - f.shiver * 0.5);

    // Sombra en el suelo: se encoge cuando sube
    final lift = (hop + jumpUp) / (r * 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, base.dy + r * 1.08),
        width: r * 1.6 * (1 - lift * 0.35),
        height: r * 0.24 * (1 - lift * 0.35),
      ),
      Paint()
        ..color = deep.withValues(alpha: 0.30 * (1 - lift * 0.5))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1),
    );

    canvas.save();
    canvas.translate(base.dx + shake, base.dy - hop - jumpUp);
    canvas.translate(0, r);
    canvas.scale(sx, sy);
    canvas.translate(0, -r);

    // Piececitos que asoman por debajo
    final step = math.sin(phase * 2) * r * 0.03;
    for (final s in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(s * r * 0.38, r * 0.93 + (s == 1 ? step : -step)), width: r * 0.42, height: r * 0.24),
        Paint()..color = deep.withValues(alpha: 0.9),
      );
    }

    // Bracitos: se balancean; saludan al tocarla o cuando está radiante
    final wave = jump > 0 ? math.sin(jump * math.pi * 6) * 0.9 : f.bounce * math.sin(phase * 3) * 0.5;
    for (final s in [-1, 1]) {
      canvas.save();
      canvas.translate(s * r * 0.98, r * 0.12);
      canvas.rotate(s * (0.5 + math.sin(phase * 2 + s) * 0.12) - (s == 1 ? wave : 0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(s * r * 0.16, 0), width: r * 0.46, height: r * 0.28),
          Radius.circular(r * 0.14),
        ),
        Paint()..color = Color.lerp(soft, deep, 0.35)!,
      );
      canvas.restore();
    }

    final body = _dropPath(r, sway);
    final bounds = Rect.fromCircle(center: Offset(0, -r * 0.25), radius: r * 1.35);
    // Aura esponjosa
    canvas.drawPath(
      body,
      Paint()
        ..color = f.color.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.28),
    );
    // Cuerpo aterciopelado: crema arriba, color suave abajo
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(soft, Colors.white, 0.35)!, soft, Color.lerp(soft, deep, 0.25)!],
          stops: const [0, 0.5, 1],
        ).createShader(bounds),
    );
    // Sombreado interior suave (volumen de malvavisco) y luz de borde
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(
      body.shift(Offset(r * 0.10, r * 0.16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.5
        ..color = deep.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
    );
    canvas.drawPath(
      body.shift(Offset(-r * 0.06, -r * 0.10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18
        ..color = Colors.white.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    // Brillo mate, difuso, arriba a la izquierda
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.42, -r * 0.55), width: r * 0.45, height: r * 0.30),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
    canvas.drawCircle(Offset(-r * 0.18, -r * 0.82), r * 0.05, Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.restore();

    _face(canvas, r, phase);
    canvas.restore();

    // Destellos alrededor (radiante)
    if (f.sparkle > 0.05) {
      for (var i = 0; i < 4; i++) {
        final a = phase + i * math.pi / 2;
        final p = Offset(size.width / 2, base.dy - r * 0.35 - hop - jumpUp) + Offset(math.cos(a) * r * 1.5, math.sin(a) * r * 1.3);
        final tint = i.isEven ? Colors.white : const Color(0xFFFFE08A);
        _star(
          canvas,
          p,
          r * (0.10 + 0.05 * math.sin(phase * 3 + i)) * f.sparkle,
          Paint()..color = tint.withValues(alpha: 0.95 * f.sparkle),
        );
      }
    }

    // Estallido al tocarla: corazones si está contenta, gotitas si no
    if (jump > 0 && jump < 1) {
      final happy = f.smile > 0.2;
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + (i - 2.5) * 0.45;
        final dist = r * (0.95 + jump * 1.1);
        final p = Offset(size.width / 2, base.dy - r * 0.6) + Offset(math.cos(a) * dist, math.sin(a) * dist * 0.9);
        final paint = Paint()..color = (happy ? const Color(0xFFFF8FC0) : const Color(0xFF9AD8FF)).withValues(alpha: (1 - jump) * 0.95);
        final k = r * 0.13 * (1 - jump * 0.4);
        if (happy) {
          _heart(canvas, p, k, paint);
        } else {
          canvas.drawPath(_dropPath(k, 0).shift(p), paint);
        }
      }
    }
  }

  /// Silueta regordeta de gota: puntita corta y blandita (se mece con [sway]) y panza ancha.
  Path _dropPath(double r, double sway) {
    final tip = Offset(sway * r * 2.0, -r * 1.45);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(tip.dx + r * 0.32, -r * 1.22, r * 1.05, -r * 0.72, r * 1.05, -r * 0.02)
      ..cubicTo(r * 1.05, r * 0.62, r * 0.6, r * 1.0, 0, r * 1.0)
      ..cubicTo(-r * 0.6, r * 1.0, -r * 1.05, r * 0.62, -r * 1.05, -r * 0.02)
      ..cubicTo(-r * 1.05, -r * 0.72, tip.dx - r * 0.32, -r * 1.22, tip.dx, tip.dy)
      ..close();
  }

  void _face(Canvas canvas, double r, double phase) {
    // Mirada: sigue el puntero o, si no hay, mira a su alrededor despacio
    final wander = look == Offset.zero ? Offset(math.sin(phase) * 0.6, math.sin(phase * 0.5) * 0.25) : look;
    final gaze = Offset(wander.dx * r * 0.08, wander.dy * r * 0.05);
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.08;

    // Mejillas sonrosadas con rayitas
    if (f.blush > 0.01) {
      final blush = Paint()
        ..color = const Color(0xFFFF7FA8).withValues(alpha: 0.55 * f.blush)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04);
      final hatch = Paint()
        ..color = const Color(0xFFFF5C8A).withValues(alpha: 0.7 * f.blush)
        ..strokeWidth = r * 0.025
        ..strokeCap = StrokeCap.round;
      for (final s in [-1, 1]) {
        final cheek = Offset(s * r * 0.60, r * 0.32) + gaze * 0.4;
        canvas.drawOval(Rect.fromCenter(center: cheek, width: r * 0.36, height: r * 0.21), blush);
        for (var k = -1; k <= 1; k++) {
          final o = cheek + Offset(k * r * 0.08, 0);
          canvas.drawLine(o + Offset(-r * 0.03, r * 0.04), o + Offset(r * 0.03, -r * 0.04), hatch);
        }
      }
    }

    // Ojos grandes y brillantes; parpadeo cada ciclo
    final blink = (t > 0.90 && t < 0.96) ? 1 - math.sin((t - 0.90) / 0.06 * math.pi) : 1.0;
    for (final s in [-1, 1]) {
      final eye = Offset(s * r * 0.36, r * 0.04) + gaze;
      final openness = (1 - f.eyeHappy) * blink * (1 - f.lid * 0.5);
      if (openness > 0.1) {
        final rect = Rect.fromCenter(center: eye, width: r * 0.30, height: r * 0.38 * openness);
        canvas.drawOval(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_ink, Color.lerp(_ink, f.color, 0.45)!],
            ).createShader(rect),
        );
        if (openness > 0.45) {
          // Reflejos: uno grande, uno pequeño y una estrellita
          canvas.drawCircle(eye + Offset(-r * 0.05, -r * 0.08 * openness), r * 0.075, Paint()..color = Colors.white);
          canvas.drawCircle(eye + Offset(r * 0.06, r * 0.07 * openness), r * 0.03, Paint()..color = Colors.white.withValues(alpha: 0.9));
          _star(canvas, eye + Offset(r * 0.06, -r * 0.03), r * 0.025, Paint()..color = Colors.white.withValues(alpha: 0.8));
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
        final y = eye.dy - r * 0.19 + r * 0.15 * f.lid;
        canvas.drawLine(Offset(eye.dx - r * 0.17, y), Offset(eye.dx + r * 0.17, y), Paint.from(line)..strokeWidth = r * 0.065);
      }
      // Cejitas: preocupación (interior alto) o enfado (interior bajo)
      if (f.browShow > 0.05) {
        final inner = eye + Offset(-s * r * 0.09, -r * 0.31 + f.brow * r * 0.08);
        final outer = eye + Offset(s * r * 0.14, -r * 0.31 - f.brow * r * 0.05);
        canvas.drawLine(inner, outer, Paint.from(line)..color = _ink.withValues(alpha: f.browShow.clamp(0.0, 1.0)));
      }
    }

    // Boquita: «ω» gatuna cuando sonríe, curva pequeña si no, abierta al reír o asustarse
    final mouthY = r * 0.30 + gaze.dy * 0.5;
    final cx = gaze.dx * 0.6;
    final mouthLine = Paint.from(line)..strokeWidth = r * 0.06;
    if (f.mouthOpen > 0.05) {
      final half = r * (0.12 + 0.05 * f.mouthOpen);
      final curve = f.smile * r * 0.12;
      final drop = r * 0.22 * f.mouthOpen;
      final mouth = Path()
        ..moveTo(cx - half, mouthY - curve * 0.2)
        ..quadraticBezierTo(cx, mouthY + curve * 0.3 - drop * 0.15, cx + half, mouthY - curve * 0.2)
        ..quadraticBezierTo(cx, mouthY + curve + drop, cx - half, mouthY - curve * 0.2)
        ..close();
      canvas.drawPath(mouth, Paint()..color = _ink);
      canvas.save();
      canvas.clipPath(mouth);
      canvas.drawCircle(Offset(cx, mouthY + curve + drop * 0.9), r * 0.13, Paint()..color = const Color(0xFFFF7FA0));
      canvas.restore();
    } else if (f.smile > 0.2) {
      final w = r * 0.08;
      final h = r * 0.06 * f.smile;
      final omega = Path()
        ..moveTo(cx - w * 2, mouthY - h * 0.2)
        ..quadraticBezierTo(cx - w, mouthY + h * 1.6, cx, mouthY)
        ..quadraticBezierTo(cx + w, mouthY + h * 1.6, cx + w * 2, mouthY - h * 0.2);
      canvas.drawPath(omega, mouthLine);
    } else {
      final half = r * (0.10 + 0.05 * f.smile.abs());
      final curve = f.smile * r * 0.14;
      final mouth = Path()
        ..moveTo(cx - half, mouthY - curve * 0.2)
        ..quadraticBezierTo(cx, mouthY + curve, cx + half, mouthY - curve * 0.2);
      canvas.drawPath(mouth, mouthLine);
    }

    // Gotita de sudor por la sien
    if (f.sweat > 0.05) {
      final slide = (t * 2) % 1;
      final p = Offset(r * 0.80, -r * 0.55 + slide * r * 0.35);
      canvas.drawPath(
        _dropPath(r * 0.11, 0).shift(p),
        Paint()..color = const Color(0xFFCDEBFF).withValues(alpha: f.sweat * (1 - slide * 0.6)),
      );
    }

    // Lágrima que cae desde el ojo
    if (f.tear > 0.05) {
      final fall = (t * 1.5) % 1;
      final p = Offset(-r * 0.40, r * 0.22 + fall * r * 0.55);
      canvas.drawPath(_dropPath(r * 0.09, 0).shift(p), Paint()..color = const Color(0xFFCDEBFF).withValues(alpha: f.tear * (1 - fall)));
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
