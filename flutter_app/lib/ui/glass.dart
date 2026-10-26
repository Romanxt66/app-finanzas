import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ribbons.dart';
import 'theme.dart';

/// Fondo con resplandores y "aurora" detrás del vidrio (`.cr-backdrop`).
/// Es estático y va en su propia capa para que no se repinte al desplazar la página.
class CrBackdrop extends StatelessWidget {
  const CrBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: c.bg)),
                Positioned.fill(child: CustomPaint(painter: _GlowPainter(c.bgGlowBrand, c.bgGlowAlt))),
                Positioned.fill(
                  child: IgnorePointer(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final vmax = math.max(box.maxWidth, box.maxHeight) / 100;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -18 * vmax,
                              right: -12 * vmax,
                              child: _Blob(size: 46 * vmax, color: c.bgGlowBrand),
                            ),
                            Positioned(
                              bottom: -16 * vmax,
                              left: -10 * vmax,
                              child: _Blob(size: 40 * vmax * 1.1, color: c.bgGlowAlt),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Haz de fibras de luz (estilo «Relay») por encima de los resplandores y bajo los paneles
        const Positioned.fill(child: RibbonField()),
        child,
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

/// Vidrio «esmerilado» sin desenfoque real: mezcla el tinte del vidrio con el fondo para que
/// el contenido se lea bien. Desenfocar lo que hay detrás en cada fotograma es muy costoso
/// en la web, así que el desenfoque real queda solo para diálogos y menús desplegables.
Color frosted(CrPalette c, Color fill, [double base = 0.55]) => Color.alphaBlend(fill, c.bg.withValues(alpha: base));

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: frosted(c, fill, widget.strong ? 0.9 : 0.55),
            borderRadius: shape,
            border: Border.all(color: widget.borderColor ?? c.glassBorder),
          ),
          foregroundDecoration: const BoxDecoration(),
          child: CustomPaint(foregroundPainter: _InsetHighlight(c.glassHighlight, widget.radius), child: body),
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
