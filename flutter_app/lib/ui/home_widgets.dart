import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../screens/insights.dart' show FinanceMood;
import 'accent.dart';
import 'charge_ticket.dart' show cssLinear;
import 'mood_face.dart';
import 'theme.dart';

// Widgets del escritorio de Android. Se pintan aquí como imágenes (el mismo cristal, tipografía y
// Alvi de la app) y la parte nativa solo las muestra y reparte los toques. Android no deja
// desenfocar lo que hay detrás de un widget: el cristal se imita con degradados translúcidos.

const _ink = Color(0xFFF5F5F5);
const _soft = Color(0xFFD4D4D4);
const _amber = Color(0xFFBDBDBD);
const _amberText = Color(0xFFE5E5E5);
const _green = Color(0xFFFFFFFF);

/// Grises de los widgets con el tono elegido en Apariencia (neutro, cálido o frío).
class WidgetTint {
  WidgetTint(AccentChoice a)
    : neon = a.tint(const Color(0xFFF5F5F5)),
      serif = a.tint(const Color(0xFFD9D9D9)),
      deep = a.tint(const Color(0xFF8A8A8A)),
      violet = a.tint(const Color(0xFF5C5C5C));
  final Color neon, serif, deep, violet;
}

/// Lo que muestran los widgets (todo ya formateado).
class HomeWidgetData {
  const HomeWidgetData({
    required this.balance,
    required this.income,
    required this.expense,
    required this.mood,
    required this.moodLine,
    this.todayLeft,
    this.todayLabel = 'disponible hoy',
    this.todayFraction = 0,
    this.todayOver = false,
    this.todayLevel = 2,
    this.charges = const [],
    this.goal,
  });

  final String balance, income, expense, moodLine;

  /// Nivel de Alvi en el resumen (0 agobiada … 4 radiante).
  final int mood;

  /// Disponible hoy («$ 46.300»); null si no hay presupuesto del mes.
  final String? todayLeft;
  final String todayLabel;
  final double todayFraction;
  final bool todayOver;
  final int todayLevel;

  /// Próximos cobros: nombre, cuándo, importe y si no alcanza.
  final List<({String name, String when, String amount, bool short})> charges;

  /// Meta: nombre, porcentaje (0–1) y lo que falta.
  final ({String name, double progress, String left, bool achieved})? goal;
}

/// Tamaños de diseño (dp) de cada widget; se pintan a 3× para que se vean nítidos.
enum HomeWidgetKind {
  quick(Size(220, 92)),
  today(Size(170, 170)),
  balance(Size(360, 172)),
  charges(Size(360, 196)),
  goal(Size(170, 170));

  const HomeWidgetKind(this.size);
  final Size size;
}

TextPainter _tp(String text, TextStyle style, {double maxWidth = double.infinity, TextAlign align = TextAlign.left}) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
  maxLines: 1,
  ellipsis: '…',
  textAlign: align,
)..layout(maxWidth: maxWidth);

TextStyle _sans(double size, FontWeight w, [Color color = _ink, double ls = 0]) => TextStyle(
  fontFamily: fontFamily,
  fontFamilyFallback: fontFallback,
  fontSize: size,
  fontWeight: w,
  color: color,
  letterSpacing: ls,
  fontFeatures: const [FontFeature.tabularFigures()],
);

TextStyle _mono(double size, [Color color = _soft]) =>
    TextStyle(fontFamily: monoFamily, fontFamilyFallback: const [fontFamily, ...fontFallback], fontSize: size, color: color);

TextStyle _serif(double size, Color color) => TextStyle(
  fontFamily: serifFamily,
  fontFamilyFallback: const [fontFamily, ...fontFallback],
  fontStyle: FontStyle.italic,
  fontSize: size,
  color: color,
);

/// Fondo de cristal del widget: velo oscuro, reflejo, tinte opcional y borde iluminado.
void _glass(Canvas canvas, Size size, {Color? tint, Color? rim, double radius = 28}) {
  final rect = Offset.zero & size;
  final rr = RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius));
  canvas.drawRRect(rr, Paint()..color = const Color(0xA80C0C0C));
  if (tint != null) {
    canvas.drawRRect(
      rr,
      Paint()..shader = cssLinear(rect, 135, [tint.withValues(alpha: 0.20), tint.withValues(alpha: 0.05)], const [0, 1]),
    );
  }
  canvas.drawRRect(
    rr,
    Paint()..shader = cssLinear(rect, 118, const [Color(0x29FFFFFF), Color(0x08FFFFFF), Color(0x00FFFFFF)], const [0, 0.4, 0.7]),
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = cssLinear(
        rect,
        135,
        [const Color(0x80FFFFFF), const Color(0x26FFFFFF), (rim ?? Colors.white).withValues(alpha: 0.45)],
        const [0, 0.45, 1],
      ),
  );
}

void _alvi(Canvas canvas, Offset topLeft, double size, int level) {
  canvas.save();
  canvas.translate(topLeft.dx, topLeft.dy);
  FacePainter(FinanceMood.faces[level.clamp(0, 4)], 0.5).paint(canvas, Size.square(size));
  canvas.restore();
}

void _pill(Canvas canvas, Rect r, {required Gradient fill, Color border = const Color(0x80FFFFFF), Color? glow}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2.4));
  if (glow != null) {
    canvas.drawRRect(
      rr,
      Paint()
        ..color = glow.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }
  canvas.drawRRect(rr, Paint()..shader = fill.createShader(r));
  canvas.drawRRect(
    rr.deflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..color = border,
  );
}

class HomeWidgetPainter extends CustomPainter {
  HomeWidgetPainter(this.kind, this.data, this.tint, {this.hidden = false});
  final HomeWidgetKind kind;
  final HomeWidgetData data;
  final WidgetTint tint;

  /// Saldo oculto («•••••••»).
  final bool hidden;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = kind.size;
    canvas.save();
    canvas.scale(size.width / s.width, size.height / s.height);
    switch (kind) {
      case HomeWidgetKind.quick:
        _quick(canvas, s);
      case HomeWidgetKind.today:
        _today(canvas, s);
      case HomeWidgetKind.balance:
        _balance(canvas, s);
      case HomeWidgetKind.charges:
        _charges(canvas, s);
      case HomeWidgetKind.goal:
        _goal(canvas, s);
    }
    canvas.restore();
  }

  void _quick(Canvas canvas, Size s) {
    _glass(canvas, s, radius: 26);
    final half = (s.width - 16 - 6) / 2;
    final left = Rect.fromLTWH(8, 8, half, s.height - 16);
    final right = Rect.fromLTWH(8 + half + 6, 8, half, s.height - 16);
    _pill(
      canvas,
      left,
      fill: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(tint.neon, Colors.white, 0.45)!, tint.neon, Color.lerp(tint.neon, Colors.black, 0.1)!],
      ),
      glow: tint.neon,
    );
    _pill(
      canvas,
      right,
      fill: LinearGradient(colors: [_green.withValues(alpha: 0.26), _green.withValues(alpha: 0.08)]),
      border: _green.withValues(alpha: 0.45),
    );
    final a = _tp('− Gasto', _sans(16, FontWeight.w800, const Color(0xFF0A0A0A)));
    a.paint(canvas, left.center - Offset(a.width / 2, a.height / 2));
    final b = _tp('+ Ingreso', _sans(16, FontWeight.w800, const Color(0xFFF5F5F5)));
    b.paint(canvas, right.center - Offset(b.width / 2, b.height / 2));
  }

  void _today(Canvas canvas, Size s) {
    final over = data.todayOver;
    _glass(canvas, s, tint: over ? _amber : null, rim: over ? _amberText : null, radius: 26);
    final c = Offset(s.width / 2, 62);
    const r = 44.0;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = const Color(0x1FFFFFFF),
    );
    final f = data.todayLeft == null ? 0.0 : (over ? 1.0 : data.todayFraction.clamp(0.0, 1.0));
    if (f > 0) {
      final color = over ? _amber : tint.neon;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * f,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
    _alvi(canvas, c - const Offset(32, 32), 64, data.todayLevel);
    final value = data.todayLeft ?? 'Sin presupuesto';
    final t = _tp(value, _sans(data.todayLeft == null ? 13 : 18, FontWeight.w800, over ? _amberText : _ink), maxWidth: s.width - 20);
    t.paint(canvas, Offset((s.width - t.width) / 2, 116));
    final l = _tp(data.todayLeft == null ? 'crea uno en la app' : data.todayLabel, _mono(11), maxWidth: s.width - 20);
    l.paint(canvas, Offset((s.width - l.width) / 2, 142));
  }

  void _balance(Canvas canvas, Size s) {
    _glass(canvas, s, tint: tint.neon);
    _alvi(canvas, Offset(s.width - 136, (s.height - 124) / 2), 124, data.mood);
    const x = 18.0;
    final w = s.width - 150;
    _tp(hidden ? 'saldo total · oculto' : 'saldo total', _mono(11.5)).paint(canvas, const Offset(x, 16));
    final big = _tp(hidden ? '•••••••' : data.balance, _sans(hidden ? 30 : 30, FontWeight.w800, _ink, hidden ? 4 : -0.7), maxWidth: w);
    big.paint(canvas, Offset(x, 54));
    if (hidden) {
      _tp('Toca para mostrar', _sans(12.5, FontWeight.w500, _soft)).paint(canvas, Offset(x, s.height - 32));
      return;
    }
    final inc = _tp('↑ ${data.income}', _mono(11, _green), maxWidth: w / 2);
    inc.paint(canvas, Offset(x, 96));
    _tp('↓ ${data.expense}', _mono(11, tint.serif), maxWidth: w / 2).paint(canvas, Offset(x + inc.width + 12, 96));
    _tp(data.moodLine, _sans(12.5, FontWeight.w500, _soft), maxWidth: w).paint(canvas, Offset(x, s.height - 32));
  }

  void _charges(Canvas canvas, Size s) {
    _glass(canvas, s);
    final title = TextPainter(
      text: TextSpan(
        style: _sans(15, FontWeight.w700),
        children: [
          const TextSpan(text: 'Próximos '),
          TextSpan(text: 'cobros', style: _serif(18, tint.serif)),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, const Offset(16, 14));
    if (data.charges.isEmpty) {
      _tp('Nada por cobrar estos días.', _sans(13, FontWeight.w500, _soft)).paint(canvas, const Offset(16, 60));
      return;
    }
    var y = 48.0;
    for (final c in data.charges.take(3)) {
      final row = Rect.fromLTWH(10, y, s.width - 20, 42);
      if (c.short) {
        final rr = RRect.fromRectAndRadius(row, const Radius.circular(14));
        canvas.drawRRect(rr, Paint()..color = _amber.withValues(alpha: 0.13));
        canvas.drawRRect(
          rr.deflate(0.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = _amberText.withValues(alpha: 0.55),
        );
      }
      final amount = _tp(c.amount, _sans(14, FontWeight.w800));
      amount.paint(canvas, Offset(row.right - 10 - amount.width, row.top + 12));
      final name = _tp(c.name, _sans(14, FontWeight.w700), maxWidth: row.width - amount.width - 40);
      name.paint(canvas, Offset(row.left + 10, row.top + 4));
      _tp(
        c.when,
        _mono(10.5, c.short ? _amberText : _soft),
        maxWidth: row.width - amount.width - 40,
      ).paint(canvas, Offset(row.left + 10, row.top + 23));
      y += 46;
    }
  }

  void _goal(Canvas canvas, Size s) {
    _glass(canvas, s, radius: 26);
    final g = data.goal;
    if (g == null) {
      _tp('metas', _mono(11)).paint(canvas, const Offset(16, 16));
      final t = TextPainter(
        text: TextSpan(text: 'Crea una meta de ahorro en la app', style: _sans(14, FontWeight.w700)),
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: s.width - 32);
      t.paint(canvas, const Offset(16, 56));
      return;
    }
    _tp('meta · ${g.name.toLowerCase()}', _mono(11), maxWidth: s.width - 32).paint(canvas, const Offset(16, 16));
    _tp('${(g.progress * 100).round()} %', _sans(28, FontWeight.w800, _ink, -0.5)).paint(canvas, const Offset(16, 56));
    final bar = Rect.fromLTWH(16, 102, s.width - 32, 10);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(5)), Paint()..color = const Color(0x1FFFFFFF));
    final fill = Rect.fromLTWH(bar.left, bar.top, bar.width * g.progress.clamp(0.0, 1.0), bar.height);
    if (fill.width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, const Radius.circular(5)),
        Paint()
          ..shader = ui.Gradient.linear(fill.centerLeft, fill.centerRight, [
            g.achieved ? const Color(0xFFD4D4D4) : tint.deep,
            g.achieved ? _green : tint.neon,
          ]),
      );
    }
    final left = TextPainter(
      text: TextSpan(
        style: _sans(12.5, FontWeight.w500, _soft),
        children: g.achieved
            ? [const TextSpan(text: '¡Meta lograda!')]
            : [const TextSpan(text: 'Faltan '), TextSpan(text: g.left, style: _sans(12.5, FontWeight.w800))],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: s.width - 32);
    left.paint(canvas, Offset(16, s.height - 34));
    if (g.achieved) _alvi(canvas, Offset(s.width - 70, 40), 60, 4);
  }

  @override
  bool shouldRepaint(HomeWidgetPainter old) => true;
}
