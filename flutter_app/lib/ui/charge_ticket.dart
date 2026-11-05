import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/reminders.dart';
import '../screens/insights.dart' show FinanceMood;
import 'glass.dart';
import 'mood_face.dart';
import 'theme.dart';

// Tarjeta de cobro de los recordatorios: un boleto de cristal sobre el fondo de la app, con
// luces de color detrás, borde iluminado, textura esmerilada y Alvi asomándose. La misma
// pintura sirve para la imagen del aviso de Android (PNG) y para las vistas previas en la app.

/// Tamaño de diseño de la tarjeta (2:1, como la imagen grande de los avisos de Android).
const ticketSize = Size(960, 480);

/// Colores de cada estado de la tarjeta (los mismos tonos del diseño aprobado).
class TicketTheme {
  const TicketTheme({
    required this.accent,
    required this.soft,
    required this.serif,
    required this.rim,
    required this.glow,
    required this.orbs,
    required this.stubTint,
    required this.face,
  });

  final Color accent, soft, serif, rim, glow, stubTint;
  final List<Color> orbs;
  final FaceExpression face;

  static TicketTheme of(TicketVariant v) => switch (v) {
    TicketVariant.covered => TicketTheme(
      accent: Color(0xFF9A9A9A),
      soft: Color(0x389A9A9A),
      serif: Color(0xFFD1D1D1),
      rim: Color(0xB3C0C0C0),
      glow: Color(0x999A9A9A),
      orbs: const [Color(0x999A9A9A), Color(0x8C555555), Color(0x52AFAFAF)],
      stubTint: Color(0x1F9A9A9A),
      face: FinanceMood.faces[3], // contenta
    ),
    TicketVariant.short => TicketTheme(
      accent: Color(0xFFC1C1C1),
      soft: Color(0x38C1C1C1),
      serif: Color(0xFFD2D2D2),
      rim: Color(0xBFD2D2D2),
      glow: Color(0x80C1C1C1),
      orbs: const [Color(0x8CA2A2A2), Color(0x80555555), Color(0x578E8E8E)],
      stubTint: Color(0x1FC1C1C1),
      face: FinanceMood.faces[1], // preocupada
    ),
    TicketVariant.paid => TicketTheme(
      accent: Color(0xFFADADAD),
      soft: Color(0x38ADADAD),
      serif: Color(0xFFCACACA),
      rim: Color(0xB3CACACA),
      glow: Color(0x80ADADAD),
      orbs: const [Color(0x80ADADAD), Color(0x80555555), Color(0x579A9A9A)],
      stubTint: Color(0x1FADADAD),
      face: FinanceMood.faces[4], // radiante
    ),
  };
}

/// Color del punto de la etiqueta.
Color chipToneColor(ChipTone tone, TicketTheme t) => switch (tone) {
  ChipTone.good => const Color(0xFFADADAD),
  ChipTone.bad => const Color(0xFF8E8E8E),
  ChipTone.neutral => t.accent,
};

const _ink = Color(0xFFF3F3F3);
const _inkSoft = Color(0xFFDADADA);

/// Gradiente lineal con el ángulo de CSS (0° hacia arriba, 90° hacia la derecha) sobre [r].
ui.Gradient cssLinear(Rect r, double degrees, List<Color> colors, List<double> stops) {
  final a = degrees * math.pi / 180;
  final dir = Offset(math.sin(a), -math.cos(a));
  final half = (r.width * math.sin(a).abs() + r.height * math.cos(a).abs()) / 2;
  return ui.Gradient.linear(r.center - dir * half, r.center + dir * half, colors, stops);
}

Paint _radial(Offset center, double radius, Color color) =>
    Paint()..shader = ui.Gradient.radial(center, radius, [color, color.withValues(alpha: 0)], [0, 0.68]);

class ChargeTicketPainter extends CustomPainter {
  ChargeTicketPainter(this.data, {this.background});

  final TicketData data;

  /// Fondo esmerilado de la app (si no está, un fondo oscuro con las luces de color).
  final ui.Image? background;

  static const _ticket = Rect.fromLTWH(36, 36, 888, 408);
  static const _notchX = 36 + 590.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = TicketTheme.of(data.variant);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / ticketSize.width, size.height / ticketSize.height);

    _scene(canvas, t);

    // Boleto: rectángulo redondeado con dos muescas en la línea de corte
    final shape = Path.combine(
      PathOperation.difference,
      Path()..addRRect(RRect.fromRectAndRadius(_ticket, const Radius.circular(34))),
      Path()
        ..addOval(Rect.fromCircle(center: Offset(_notchX, _ticket.top), radius: 25.5))
        ..addOval(Rect.fromCircle(center: Offset(_notchX, _ticket.bottom), radius: 25.5)),
    );
    canvas.save();
    canvas.clipPath(shape);
    // Cristal: lo de detrás, desenfocado y más saturado
    canvas.saveLayer(_ticket.inflate(2), Paint()..imageFilter = glassFilter(26, 1.7));
    _scene(canvas, t);
    canvas.restore();
    canvas.drawRect(_ticket, Paint()..color = const Color(0x61090909));
    canvas.drawRect(
      _ticket,
      Paint()..shader = cssLinear(_ticket, 135, const [Color(0x1FFFFFFF), Color(0x0AFFFFFF), Color(0x14FFFFFF)], const [0, 0.55, 1]),
    );
    canvas.drawRect(
      _ticket,
      Paint()..shader = cssLinear(_ticket, 118, const [Color(0x33FFFFFF), Color(0x0DFFFFFF), Color(0x00FFFFFF)], const [0, 0.22, 0.44]),
    );
    _grain(canvas);
    // Talón con el tinte del estado
    final stub = Rect.fromLTRB(_notchX, _ticket.top, _ticket.right, _ticket.bottom);
    canvas.drawRect(
      stub,
      Paint()..shader = ui.Gradient.linear(stub.topCenter, stub.bottomCenter, [t.stubTint, t.stubTint.withValues(alpha: 0)]),
    );
    // Reflejo interior en el borde superior
    canvas.drawLine(
      Offset(_ticket.left + 30, _ticket.top + 1.5),
      Offset(_ticket.right - 30, _ticket.top + 1.5),
      Paint()
        ..strokeWidth = 1.5
        ..shader = ui.Gradient.linear(
          Offset(_ticket.left, 0),
          Offset(_ticket.right, 0),
          const [Color(0x00FFFFFF), Color(0x6BFFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.25, 0.75, 1],
        ),
    );
    canvas.restore();

    // Borde iluminado: blanco arriba a la izquierda, color del estado abajo a la derecha
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = cssLinear(
          _ticket,
          135,
          [const Color(0xB8FFFFFF), const Color(0x1FFFFFFF), const Color(0x0DFFFFFF), t.rim],
          const [0, 0.30, 0.62, 1],
        ),
    );

    // Línea de corte
    final dash = Paint()
      ..color = const Color(0x47FFFFFF)
      ..strokeWidth = 3;
    for (var y = _ticket.top + 34; y < _ticket.bottom - 34; y += 18) {
      canvas.drawLine(Offset(_notchX, y), Offset(_notchX, math.min(y + 10, _ticket.bottom - 34)), dash);
    }

    _main(canvas, t);
    _stub(canvas, t);

    // Alvi se asoma por la esquina, por fuera del boleto
    canvas.save();
    canvas.translate(ticketSize.width - 18 - 200, ticketSize.height + 6 - 200);
    FacePainter(t.face, 0.5).paint(canvas, const Size.square(200));
    canvas.restore();

    canvas.restore();
  }

  /// Fondo: imagen de la app con velo, tres luces de color y el halo bajo el boleto.
  void _scene(Canvas canvas, TicketTheme t) {
    const full = Rect.fromLTWH(0, 0, 960, 480);
    canvas.drawRect(full, Paint()..color = const Color(0xFF010101));
    final img = background;
    if (img != null) {
      final dst = const Rect.fromLTWH(-40, -40, 1040, 560);
      final scale = math.max(dst.width / img.width, dst.height / img.height);
      final src = Rect.fromCenter(center: Offset(img.width / 2, img.height / 2), width: dst.width / scale, height: dst.height / scale);
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium);
    }
    canvas.drawRect(full, Paint()..color = const Color(0x57010101));
    canvas.drawCircle(const Offset(755, 85), 235, _radial(const Offset(755, 85), 235, t.orbs[0]));
    canvas.drawCircle(const Offset(60, 440), 210, _radial(const Offset(60, 440), 210, t.orbs[1]));
    canvas.drawCircle(const Offset(840, 430), 140, _radial(const Offset(840, 430), 140, t.orbs[2]));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(90, 96, 780, 340), const Radius.circular(40)),
      Paint()
        ..color = t.glow.withValues(alpha: t.glow.a * 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
    );
  }

  /// Textura esmerilada: puntos claros y oscuros muy tenues (siempre los mismos).
  void _grain(Canvas canvas) {
    final rnd = math.Random(7);
    List<double> points(int n) => [
      for (var i = 0; i < n; i++) ...[_ticket.left + rnd.nextDouble() * _ticket.width, _ticket.top + rnd.nextDouble() * _ticket.height],
    ];
    final light = Float32List.fromList(points(5000));
    final dark = Float32List.fromList(points(5000));
    canvas.drawRawPoints(
      ui.PointMode.points,
      light,
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 1.6,
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      dark,
      Paint()
        ..color = const Color(0x1A000000)
        ..strokeWidth = 1.6,
    );
  }

  TextPainter _text(InlineSpan span, double maxWidth, {int maxLines = 1}) =>
      TextPainter(text: span, textDirection: TextDirection.ltr, maxLines: maxLines, ellipsis: '…')..layout(maxWidth: maxWidth);

  static TextStyle _sans(double size, FontWeight w, {Color color = _ink, double ls = 0, double? height}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    fontSize: size,
    fontWeight: w,
    color: color,
    letterSpacing: ls,
    height: height,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle _mono(double size, Color color) => TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: const [fontFamily, ...fontFallback],
    fontSize: size,
    color: color,
    height: 1.25,
  );

  void _main(Canvas canvas, TicketTheme t) {
    const left = 36 + 44.0;
    const width = 590 - 88.0;
    var y = 36 + 38.0;

    // Comercio: círculo con la inicial, nombre y cuenta
    final title = _text(TextSpan(text: data.merchant, style: _sans(44, FontWeight.w800, ls: -0.5, height: 1.1)), width - 96);
    final meta = _text(TextSpan(text: data.meta, style: _mono(23, _inkSoft)), width - 96);
    final rowH = math.max(76.0, title.height + 2 + meta.height);
    final center = Offset(left + 38, y + rowH / 2);
    canvas.drawCircle(
      center,
      30,
      Paint()
        ..color = t.glow.withValues(alpha: t.glow.a * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      center,
      38,
      Paint()
        ..shader = ui.Gradient.radial(
          center + const Offset(-38 * 0.36, -38 * 0.48),
          76,
          [const Color(0x8CFFFFFF), const Color(0x1AFFFFFF), t.soft],
          [0, 0.42, 1],
        ),
    );
    canvas.drawCircle(
      center,
      36.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = t.accent,
    );
    final initial = _text(
      TextSpan(
        text: data.initial,
        style: _sans(36, FontWeight.w800, color: Colors.white),
      ),
      76,
    );
    initial.paint(canvas, center - Offset(initial.width / 2, initial.height / 2));
    final textX = left + 96;
    final textTop = y + (rowH - title.height - 2 - meta.height) / 2;
    title.paint(canvas, Offset(textX, textTop));
    meta.paint(canvas, Offset(textX, textTop + title.height + 2));
    y += rowH + 16;

    // «Se cobra *mañana*»
    final lead = _text(
      TextSpan(
        style: _sans(36, FontWeight.w600, height: 1.15),
        children: [
          TextSpan(text: '${data.lead} '),
          TextSpan(
            text: data.accent,
            style: TextStyle(
              fontFamily: serifFamily,
              fontFamilyFallback: const [fontFamily, ...fontFallback],
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              fontSize: 42,
              color: t.serif,
            ),
          ),
        ],
      ),
      width,
    );
    lead.paint(canvas, Offset(left, y));
    y += lead.height + 16;

    // Importe grande y moneda (se encoge si no cabe)
    final code = _text(TextSpan(text: data.currency, style: _mono(24, _inkSoft)), 120);
    var size = 92.0;
    late TextPainter amount;
    do {
      amount = _text(
        TextSpan(
          text: data.amount,
          style: _sans(size, FontWeight.w800, ls: -2 * size / 92, height: 0.95),
        ),
        double.infinity,
      );
      if (amount.width + 14 + code.width <= width) break;
      size -= 4;
    } while (size > 52);
    amount.paint(canvas, Offset(left, y));
    final baseline = y + amount.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    code.paint(canvas, Offset(left + amount.width + 14, baseline - code.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
    y += math.max(amount.height, 87.4) + 16;

    // Etiqueta de cristal con el punto de color
    final chip = _text(TextSpan(text: data.chip, style: _mono(23, _ink)), width - 54);
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, y, 18 + 12 + 12 + chip.width + 18, chip.height + 16),
      const Radius.circular(999),
    );
    canvas.drawRRect(
      chipRect,
      Paint()..shader = cssLinear(chipRect.outerRect, 135, const [Color(0x2EFFFFFF), Color(0x0DFFFFFF)], const [0, 1]),
    );
    canvas.drawRRect(
      chipRect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x42FFFFFF),
    );
    final dot = Offset(left + 18 + 6, y + chipRect.height / 2);
    final tone = chipToneColor(data.chipTone, t);
    canvas.drawCircle(
      dot,
      9,
      Paint()
        ..color = tone.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(dot, 6, Paint()..color = tone);
    chip.paint(canvas, Offset(left + 18 + 12 + 12, y + 8));
  }

  void _stub(Canvas canvas, TicketTheme t) {
    const left = _notchX + 3 + 30;
    const width = 888 - 593 - 60.0;
    var y = 36 + 38.0;
    final weekday = _text(TextSpan(text: data.weekday, style: _mono(24, t.serif)), width);
    weekday.paint(canvas, Offset(left, y));
    y += weekday.height;
    final day = _text(
      TextSpan(
        text: data.day,
        style: _sans(124, FontWeight.w800, ls: -4, height: 1).copyWith(
          shadows: const [Shadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 2))],
        ),
      ),
      width,
    );
    day.paint(canvas, Offset(left - 4, y));
    y += day.height;
    _text(TextSpan(text: data.month, style: _mono(28, _inkSoft)), width).paint(canvas, Offset(left, y));
  }

  @override
  bool shouldRepaint(ChargeTicketPainter old) => old.data.signature != data.signature || old.background != background;
}

/// Burbuja de cristal con Alvi dentro (icono grande del aviso). [size] en píxeles.
class AlviBubblePainter extends CustomPainter {
  AlviBubblePainter(this.variant);
  final TicketVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = TicketTheme.of(variant);
    final s = size.shortestSide / 56; // diseño a 56 px
    final center = size.center(Offset.zero);
    final r = 28 * s - 1;
    final circle = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(circle.left + circle.width * 0.30, circle.top + circle.height * 0.22),
          r * 2 * 0.95,
          [const Color(0x75FFFFFF), const Color(0x14FFFFFF), t.accent.withValues(alpha: 0.36)],
          [0, 0.44, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.translate(circle.left - 6 * s, circle.top + 1 * s);
    FacePainter(t.face, 0.5).paint(canvas, Size.square(66 * s));
    canvas.restore();
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s)
        ..color = const Color(0x6BFFFFFF),
    );
    // Reflejo superior
    canvas.drawArc(
      circle.deflate(s * 1.5),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s
        ..color = const Color(0x8CFFFFFF),
    );
  }

  @override
  bool shouldRepaint(AlviBubblePainter old) => old.variant != variant;
}

/// Pinta con [painter] una imagen de [size] píxeles y la devuelve en PNG.
Future<Uint8List> paintToPng(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

ui.Image? _frost;

/// Fondo esmerilado de la app ya decodificado (para pintar la tarjeta fuera de los widgets).
Future<ui.Image?> loadTicketBackground() async {
  if (_frost != null) return _frost;
  try {
    final data = await rootBundle.load(frostAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 1040);
    _frost = (await codec.getNextFrame()).image;
  } catch (_) {
    // Sin el fondo la tarjeta se pinta igual, sobre oscuro con las luces de color
  }
  return _frost;
}

/// Vista de la tarjeta dentro de la app (vistas previas): usa el fondo del cristal si ya está cargado.
class ChargeTicket extends StatelessWidget {
  const ChargeTicket({super.key, required this.data, this.semanticLabel});
  final TicketData data;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final image = FrostScope.maybeOf(context)?.image;
    return Semantics(
      label: semanticLabel ?? '${data.merchant}: ${data.lead} ${data.accent}, ${data.amount}. ${data.chip}',
      image: true,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 2,
        child: RepaintBoundary(
          child: CustomPaint(painter: ChargeTicketPainter(data, background: image)),
        ),
      ),
    );
  }
}

/// Burbuja de cristal con Alvi, para vistas previas y la hoja de cobros.
class AlviBubble extends StatelessWidget {
  const AlviBubble({super.key, required this.variant, this.size = 56, this.semanticLabel});
  final TicketVariant variant;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = TicketTheme.of(variant);
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: t.accent.withValues(alpha: 0.40), blurRadius: size * 0.36)],
        ),
        child: SizedBox.square(
          dimension: size,
          child: RepaintBoundary(child: CustomPaint(painter: AlviBubblePainter(variant))),
        ),
      ),
    );
  }
}
