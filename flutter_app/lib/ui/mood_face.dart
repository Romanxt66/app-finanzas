import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

/// Rasgos de una carita. Todos son números para poder pasar de una expresión a otra suavemente.
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
      other.sparkle == sparkle;

  @override
  int get hashCode => Object.hash(color, smile, mouthOpen, eyeHappy, lid, brow, browShow, blush, sweat, tear, sparkle);
}

/// Carita animada: cambia de expresión con suavidad, respira, parpadea y, si [lively], los detalles
/// (destellos, gota de sudor, lágrima) se mueven. Con «reducir movimiento» queda quieta.
class MoodFace extends StatefulWidget {
  const MoodFace({super.key, required this.expression, this.size = 64, this.lively = true, this.semanticLabel});
  final FaceExpression expression;
  final double size;
  final bool lively;
  final String? semanticLabel;

  @override
  State<MoodFace> createState() => MoodFaceState();
}

class MoodFaceState extends State<MoodFace> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final AnimationController _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);
  late final AnimationController _boing = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late FaceExpression _from = widget.expression;

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

  /// Rebote breve, por ejemplo al tocar la carita.
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
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _morph, _boing]),
            builder: (context, _) {
              final face = FaceExpression.lerp(_from, widget.expression, crEase.transform(_morph.value));
              final b = _boing.value;
              final squash = b == 0 ? 0.0 : math.sin(b * math.pi * 3) * (1 - b) * 0.12;
              return Transform.scale(
                scaleX: 1 + squash,
                scaleY: 1 - squash,
                alignment: Alignment.bottomCenter,
                child: CustomPaint(painter: FacePainter(face, _idle.value)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  FacePainter(this.f, this.t);
  final FaceExpression f;

  /// Fase del ciclo de reposo (0–1): respiración, parpadeo y detalles.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.80;
    final wave = math.sin(t * math.pi * 2);
    final c = Offset(size.width / 2, size.height / 2 + wave * r * 0.04);

    // Halo y cara con volumen
    canvas.drawCircle(
      c,
      r * 1.08,
      Paint()
        ..color = f.color.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [Color.lerp(f.color, Colors.white, 0.45)!, f.color, Color.lerp(f.color, Colors.black, 0.18)!],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ink = Color.lerp(f.color, const Color(0xFF1A0420), 0.86)!;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.10;

    // Mejillas
    if (f.blush > 0.01) {
      final blush = Paint()..color = const Color(0xFFFF5C8A).withValues(alpha: 0.45 * f.blush);
      for (final s in [-1, 1]) {
        canvas.drawOval(Rect.fromCenter(center: c + Offset(s * r * 0.55, r * 0.18), width: r * 0.34, height: r * 0.18), blush);
      }
    }

    // Ojos: redondos que pasan a arco feliz; parpadeo cada ciclo
    final blink = (t > 0.90 && t < 0.96) ? 1 - math.sin((t - 0.90) / 0.06 * math.pi) : 1.0;
    for (final s in [-1, 1]) {
      final eye = c + Offset(s * r * 0.36, -r * 0.16);
      final openness = (1 - f.eyeHappy) * blink * (1 - f.lid * 0.55);
      if (openness > 0.08) {
        canvas.drawOval(Rect.fromCenter(center: eye, width: r * 0.22, height: r * 0.30 * openness), Paint()..color = ink);
        // Brillo del ojo
        if (openness > 0.5) {
          canvas.drawCircle(
            eye + Offset(-r * 0.04, -r * 0.06 * openness),
            r * 0.045,
            Paint()..color = Colors.white.withValues(alpha: 0.85),
          );
        }
      }
      if (f.eyeHappy > 0.05) {
        final arc = Path()
          ..moveTo(eye.dx - r * 0.13, eye.dy + r * 0.04)
          ..quadraticBezierTo(eye.dx, eye.dy - r * 0.16 * f.eyeHappy, eye.dx + r * 0.13, eye.dy + r * 0.04);
        canvas.drawPath(arc, line..color = ink.withValues(alpha: f.eyeHappy.clamp(0.0, 1.0)));
        line.color = ink;
      } else if (openness <= 0.08) {
        canvas.drawLine(eye - Offset(r * 0.11, 0), eye + Offset(r * 0.11, 0), line);
      }
      // Párpado caído (aburrido)
      if (f.lid > 0.05 && f.eyeHappy < 0.5) {
        canvas.drawLine(
          eye + Offset(-r * 0.15, -r * 0.05 + r * 0.08 * (1 - f.lid)),
          eye + Offset(r * 0.15, -r * 0.05 + r * 0.08 * (1 - f.lid)),
          line..strokeWidth = r * 0.08,
        );
        line.strokeWidth = r * 0.10;
      }
      // Cejas: preocupación (interior alto) o enfado (interior bajo)
      if (f.browShow > 0.05) {
        final inner = eye + Offset(-s * r * 0.10, -r * 0.24 + f.brow * r * 0.10);
        final outer = eye + Offset(s * r * 0.16, -r * 0.24 - f.brow * r * 0.06);
        canvas.drawLine(inner, outer, line..color = ink.withValues(alpha: f.browShow.clamp(0.0, 1.0)));
        line.color = ink;
      }
    }

    // Boca: curva que se abre en sonrisa o se cierra en tristeza
    final mouthY = c.dy + r * 0.36;
    final half = r * (0.30 + 0.06 * f.smile.abs());
    final curve = f.smile * r * 0.30;
    final upper = Path()
      ..moveTo(c.dx - half, mouthY - curve * 0.25)
      ..quadraticBezierTo(c.dx, mouthY + curve, c.dx + half, mouthY - curve * 0.25);
    if (f.mouthOpen > 0.05) {
      final drop = r * 0.36 * f.mouthOpen;
      final mouth = Path()
        ..moveTo(c.dx - half, mouthY - curve * 0.25)
        ..quadraticBezierTo(c.dx, mouthY + curve * 0.4 - drop * 0.2, c.dx + half, mouthY - curve * 0.25)
        ..quadraticBezierTo(c.dx, mouthY + curve + drop, c.dx - half, mouthY - curve * 0.25)
        ..close();
      canvas.drawPath(mouth, Paint()..color = ink);
      // Lengua
      canvas.save();
      canvas.clipPath(mouth);
      canvas.drawCircle(Offset(c.dx, mouthY + curve + drop * 0.85), r * 0.20, Paint()..color = const Color(0xFFFF6B8F));
      canvas.restore();
    } else {
      canvas.drawPath(upper, line);
    }

    // Gota de sudor que resbala
    if (f.sweat > 0.05) {
      final slide = (t * 2 % 1);
      final p = c + Offset(r * 0.78, -r * 0.42 + slide * r * 0.25);
      final drop = Path()
        ..moveTo(p.dx, p.dy - r * 0.16)
        ..quadraticBezierTo(p.dx + r * 0.11, p.dy, p.dx, p.dy + r * 0.07)
        ..quadraticBezierTo(p.dx - r * 0.11, p.dy, p.dx, p.dy - r * 0.16);
      canvas.drawPath(drop, Paint()..color = const Color(0xFF7DD3FC).withValues(alpha: f.sweat * (1 - slide * 0.5)));
    }

    // Lágrima bajo el ojo
    if (f.tear > 0.05) {
      final fall = (t * 1.5 % 1);
      final p = c + Offset(-r * 0.40, -r * 0.02 + fall * r * 0.42);
      canvas.drawCircle(p, r * 0.075, Paint()..color = const Color(0xFF7DD3FC).withValues(alpha: f.tear * (1 - fall)));
    }

    // Destellos que giran alrededor
    if (f.sparkle > 0.05) {
      final star = Paint()..color = Colors.white.withValues(alpha: 0.9 * f.sparkle);
      for (var i = 0; i < 3; i++) {
        final a = t * math.pi * 2 + i * math.pi * 2 / 3;
        final p = c + Offset(math.cos(a) * r * 1.28, math.sin(a) * r * 1.18);
        final k = r * (0.10 + 0.05 * math.sin(t * math.pi * 6 + i)) * f.sparkle;
        final path = Path()
          ..moveTo(p.dx, p.dy - k * 1.6)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + k * 1.6, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + k * 1.6)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - k * 1.6, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - k * 1.6);
        canvas.drawPath(path, star);
      }
    }
  }

  @override
  bool shouldRepaint(FacePainter old) => old.f != f || old.t != t;
}
