import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ribbons.dart';
import 'theme.dart';

/// Fondo con resplandores y "aurora" a la deriva detrás del vidrio (`.cr-backdrop`).
class CrBackdrop extends StatefulWidget {
  const CrBackdrop({super.key, required this.child});
  final Widget child;

  @override
  State<CrBackdrop> createState() => _CrBackdropState();
}

class _CrBackdropState extends State<CrBackdrop> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 26));
  late final AnimationController _b = AnimationController(vsync: this, duration: const Duration(seconds: 32));
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = context.reduceMotion;
    if (reduce && _running) {
      _a.stop();
      _b.stop();
      _running = false;
    } else if (!reduce && !_running) {
      _a.repeat(reverse: true);
      _b.repeat(reverse: true);
      _running = true;
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: c.bg)),
        Positioned.fill(child: CustomPaint(painter: _GlowPainter(c.bgGlowBrand, c.bgGlowAlt))),
        // Haz de fibras de luz (estilo «Relay») por encima de los resplandores y bajo el vidrio
        const Positioned.fill(child: RibbonField()),
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, box) {
                final vmax = math.max(box.maxWidth, box.maxHeight) / 100;
                return AnimatedBuilder(
                  animation: Listenable.merge([_a, _b]),
                  builder: (context, _) {
                    final ta = Curves.easeInOut.transform(_a.value);
                    final tb = Curves.easeInOut.transform(_b.value);
                    final sa = 46 * vmax;
                    final sb = 40 * vmax;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -18 * vmax,
                          right: -12 * vmax,
                          child: Transform.translate(
                            offset: Offset(-8 * vmax * ta, 10 * vmax * ta),
                            child: Transform.scale(
                              scale: 1 + 0.15 * ta,
                              child: _Blob(size: sa, color: c.bgGlowBrand),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -16 * vmax,
                          left: -10 * vmax,
                          child: Transform.translate(
                            offset: Offset(10 * vmax * tb, -8 * vmax * tb),
                            child: Transform.scale(
                              scale: 1.1 - 0.15 * tb,
                              child: _Blob(size: sb, color: c.bgGlowAlt),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.55,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)], stops: const [0, 0.65]),
      ),
    ),
  );
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.brand, this.alt);
  final Color brand, alt;

  void _ellipse(Canvas canvas, Offset center, double rx, double ry, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0, 0.7],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(rx, ry);
    canvas.drawCircle(Offset.zero, 1, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _ellipse(canvas, Offset(size.width * 0.10, size.height * 0.06), 520, 380, brand);
    _ellipse(canvas, Offset(size.width * 0.94, size.height * 0.98), 460, 360, alt);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.brand != brand || old.alt != alt;
}

/// Pinta el borde interior superior de 1 px (`inset 0 1px 0 glass-highlight`).
class _InsetHighlight extends CustomPainter {
  _InsetHighlight(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final outer = Path()..addRRect(rrect);
    final inner = Path()..addRRect(rrect.shift(const Offset(0, 1)));
    canvas.clipRRect(rrect);
    canvas.drawPath(Path.combine(PathOperation.difference, outer, inner), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InsetHighlight old) => old.color != color || old.radius != radius;
}

ui.ImageFilter glassFilter(double blur, [double saturate = 1.6]) {
  final s = saturate;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sat = ColorFilter.matrix(<double>[
    lr + (1 - lr) * s, lg - lg * s, lb - lb * s, 0, 0, //
    lr - lr * s, lg + (1 - lg) * s, lb - lb * s, 0, 0,
    lr - lr * s, lg - lg * s, lb + (1 - lb) * s, 0, 0,
    0, 0, 0, 1, 0,
  ]);
  return ui.ImageFilter.compose(
    outer: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp),
    inner: sat,
  );
}

/// Módulo de vidrio (`.cr-glass`). [lift] da la elevación suave al pasar el puntero.
class Glass extends StatefulWidget {
  const Glass({
    super.key,
    required this.child,
    this.strong = false,
    this.radius = radiusLg,
    this.padding,
    this.blur = blurMd,
    this.lift = false,
    this.onTap,
    this.margin,
    this.clip = true,
    this.borderColor,
  });
  final Widget child;
  final bool strong;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final bool lift;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool clip;
  final Color? borderColor;

  @override
  State<Glass> createState() => _GlassState();
}

class _GlassState extends State<Glass> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hovered = widget.lift && _hover && !context.reduceMotion;
    final shape = BorderRadius.circular(widget.radius);
    final fill = (widget.strong || (widget.lift && _hover)) ? c.glassStrong : c.glass;
    Widget body = widget.padding == null ? widget.child : Padding(padding: widget.padding!, child: widget.child);
    if (widget.onTap != null) {
      body = GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: body);
    }
    Widget glass = DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: [widget.strong ? c.shadowLift : c.shadowGlass]),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: glassFilter(widget.blur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: shape,
              border: Border.all(color: widget.borderColor ?? c.glassBorder),
            ),
            foregroundDecoration: const BoxDecoration(),
            child: CustomPaint(foregroundPainter: _InsetHighlight(c.glassHighlight, widget.radius), child: body),
          ),
        ),
      ),
    );
    if (widget.lift) {
      glass = MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedSlide(
          offset: hovered ? const Offset(0, -2 / 100) : Offset.zero,
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          child: glass,
        ),
      );
    }
    return widget.margin == null ? glass : Padding(padding: widget.margin!, child: glass);
  }
}
