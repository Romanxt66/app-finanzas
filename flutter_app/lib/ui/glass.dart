import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'theme.dart';

const backgroundAsset = 'assets/backgrounds/fondo.jpg';

/// Versión del fondo ya desenfocada: las tarjetas pintan su trozo y parecen cristal esmerilado
/// sin aplicar un desenfoque en tiempo real (que en la web es muy costoso).
const frostAsset = 'assets/backgrounds/fondo_esmerilado.jpg';

/// Fondo con imagen (`.cr-backdrop`): la foto, un velo para que el texto se lea y dos resplandores
/// tenues. Es estático y va en su propia capa para que no se repinte al desplazar la página.
class CrBackdrop extends StatefulWidget {
  const CrBackdrop({super.key, required this.child});
  final Widget child;

  @override
  State<CrBackdrop> createState() => _CrBackdropState();
}

class _CrBackdropState extends State<CrBackdrop> {
  final _key = GlobalKey();
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _frost = info.image);
  });
  ui.Image? _frost;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = const AssetImage(frostAsset).resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = c.bg.computeLuminance() < 0.2;
    return FrostScope(
      image: _frost,
      backdrop: _key,
      dark: dark,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: _key,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: c.bg),
                  const Image(image: AssetImage(backgroundAsset), fit: BoxFit.cover, gaplessPlayback: true),
                  // Velo: oscuro (o claro) y algo más denso abajo, donde va el contenido
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: dark
                            ? [c.bg.withValues(alpha: 0.45), c.bg.withValues(alpha: 0.72)]
                            : [c.bg.withValues(alpha: 0.70), c.bg.withValues(alpha: 0.84)],
                      ),
                    ),
                  ),
                  CustomPaint(painter: _GlowPainter(Colors.transparent, c.bgGlowBrand, c.bgGlowAlt)),
                ],
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Lo que necesita el cristal para pintar su trozo de fondo desenfocado.
class FrostScope extends InheritedWidget {
  const FrostScope({super.key, required this.image, required this.backdrop, required this.dark, required super.child});
  final ui.Image? image;
  final GlobalKey backdrop;
  final bool dark;

  static FrostScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostScope>();

  @override
  bool updateShouldNotify(FrostScope old) => old.image != image || old.backdrop != backdrop || old.dark != dark;
}

/// Pinta, bajo su hijo, la porción del fondo desenfocado que queda justo detrás en pantalla.
/// Se recalcula en cada repintado (al desplazar, la zona desplazable repinta su contenido).
class Frost extends SingleChildRenderObjectWidget {
  const Frost({super.key, required this.image, required this.backdrop, super.child});
  final ui.Image image;
  final GlobalKey backdrop;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFrost(image, backdrop);

  @override
  void updateRenderObject(BuildContext context, RenderFrost renderObject) {
    renderObject
      ..image = image
      ..backdrop = backdrop;
  }
}

class RenderFrost extends RenderProxyBox {
  RenderFrost(this._image, this.backdrop);
  ui.Image _image;
  GlobalKey backdrop;

  set image(ui.Image v) {
    if (v == _image) return;
    _image = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bd = backdrop.currentContext?.findRenderObject();
    if (bd is RenderBox && bd.attached && attached && bd.hasSize) {
      final origin = MatrixUtils.transformPoint(getTransformTo(bd), Offset.zero);
      final imageSize = Size(_image.width.toDouble(), _image.height.toDouble());
      final fitted = applyBoxFit(BoxFit.cover, imageSize, bd.size);
      final src = Alignment.center.inscribe(fitted.source, Offset.zero & imageSize);
      final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & bd.size).shift(offset - origin);
      final canvas = context.canvas;
      canvas.save();
      canvas.clipRect(offset & size);
      canvas.drawImageRect(_image, src, dst, Paint()..filterQuality = FilterQuality.low);
      canvas.restore();
    }
    super.paint(context, offset);
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.bg, this.brand, this.alt);
  final Color bg, brand, alt;

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
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    _ellipse(canvas, Offset(size.width * 0.10, size.height * 0.06), 520, 380, brand);
    _ellipse(canvas, Offset(size.width * 0.94, size.height * 0.98), 460, 360, alt);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.bg != bg || old.brand != brand || old.alt != alt;
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

Widget _frosted(FrostScope? scope, Widget child) =>
    scope == null ? child : Frost(image: scope.image!, backdrop: scope.backdrop, child: child);

/// Tinte sobre el fondo desenfocado: deja ver el color de la imagen y mantiene el texto legible.
Color frostTint(CrPalette c, bool dark, {bool strong = false}) =>
    dark ? const Color(0xFF0B0612).withValues(alpha: strong ? 0.66 : 0.52) : Colors.white.withValues(alpha: strong ? 0.72 : 0.58);

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
    final scope = FrostScope.maybeOf(context);
    final frost = scope?.image == null ? null : scope;
    Widget body = widget.padding == null ? widget.child : Padding(padding: widget.padding!, child: widget.child);
    if (widget.onTap != null) {
      body = GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: body);
    }
    Widget glass = DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: [widget.strong ? c.shadowLift : c.shadowGlass]),
      child: ClipRRect(
        borderRadius: shape,
        child: _frosted(
          frost,
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: frost == null
                  ? frosted(c, fill, widget.strong ? 0.9 : 0.55)
                  : frostTint(c, frost.dark, strong: widget.strong || (widget.lift && _hover)),
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
