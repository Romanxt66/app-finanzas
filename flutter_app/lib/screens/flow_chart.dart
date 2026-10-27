import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/reference.dart';
import '../ui/deal_card.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

typedef TrendPoint = ({String month, double income, double expense});

/// «Flujo de dinero»: ingresos (línea continua con área) y gastos (línea punteada) en curvas suaves,
/// con tooltip al pasar el puntero y, debajo, el reparto del gasto del mes en una barra segmentada.
class FlowCard extends StatelessWidget {
  const FlowCard({super.key, required this.trend, required this.currency, required this.byCategory, required this.names});
  final List<TrendPoint> trend;
  final String? currency;
  final List<({String? categoryId, double total})> byCategory;
  final RefData names;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final income = trend.fold<double>(0, (a, m) => a + m.income);
    final expense = trend.fold<double>(0, (a, m) => a + m.expense);
    final half = trend.length ~/ 2;
    final recent = trend.skip(half).fold<double>(0, (a, m) => a + m.income);
    final before = trend.take(half).fold<double>(0, (a, m) => a + m.income);
    final change = before > 0 ? (recent - before) / before * 100 : null;
    Widget legend(Color color, String text, {bool dashed = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dashed ? 14 : 8,
          height: dashed ? 2 : 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(text, style: CrText.mono(c.inkMuted, size: 11)),
      ],
    );
    return CrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            runSpacing: space3,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ingresos de ${trend.length} meses', style: CrText.overline(c.inkFaint)),
                  const SizedBox(height: space1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedMoney(value: income, currency: currency, style: CrText.display(c.ink, size: 34)),
                      if (change != null) ...[const SizedBox(width: space3), Delta(change)],
                    ],
                  ),
                  Text('gastaste ${formatMoney(expense, currency)} en el mismo periodo', style: CrText.mono(c.inkFaint, size: 11.5)),
                ],
              ),
              Wrap(spacing: space4, children: [legend(c.neon, 'ingresos'), legend(c.inkMuted, 'gastos', dashed: true)]),
            ],
          ),
          const SizedBox(height: space4),
          FlowChart(trend: trend, currency: currency),
          if (byCategory.isNotEmpty) ...[const SizedBox(height: space4), CategoryStrip(rows: byCategory, names: names, currency: currency)],
        ],
      ),
    );
  }
}

class FlowChart extends StatefulWidget {
  const FlowChart({super.key, required this.trend, required this.currency, this.height = 240});
  final List<TrendPoint> trend;
  final String? currency;
  final double height;

  @override
  State<FlowChart> createState() => _FlowChartState();
}

class _FlowChartState extends State<FlowChart> {
  int? _hover;

  static const _left = 46.0;
  static const _bottom = 26.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = widget.trend;
    if (t.isEmpty) return SizedBox(height: widget.height, child: const CrEmpty('Aún no hay meses para comparar.'));
    return Semantics(
      label: 'Ingresos y gastos de los últimos ${t.length} meses',
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, box) {
            final plotW = box.maxWidth - _left - 12;
            final step = t.length > 1 ? plotW / (t.length - 1) : plotW;
            double xOf(int i) => _left + (t.length > 1 ? step * i : plotW / 2);
            final shown = _hover ?? t.length - 1;
            final scale = _FlowPainter.scaleFor(t);
            final plotH = widget.height - _bottom - 16;
            final py = 16 + plotH * (1 - (t[shown].income / scale.max).clamp(0, 1));
            return MouseRegion(
              onHover: (e) {
                final i = ((e.localPosition.dx - _left) / (t.length > 1 ? step : plotW) + 0.5).floor().clamp(0, t.length - 1);
                setState(() => _hover = i);
              },
              onExit: (_) => setState(() => _hover = null),
              child: GestureDetector(
                onTapDown: (e) {
                  final i = ((e.localPosition.dx - _left) / (t.length > 1 ? step : plotW) + 0.5).floor().clamp(0, t.length - 1);
                  setState(() => _hover = i);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
                        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 1200),
                        curve: crEase,
                        builder: (context, v, _) => CustomPaint(painter: _FlowPainter(t, v, c, shown, _left, _bottom, scale)),
                      ),
                    ),
                    // Tooltip flotante sobre el punto (como «$70k · Sep 22»)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: crEase,
                      left: (xOf(shown) - 74).clamp(0, math.max(0, box.maxWidth - 148)),
                      top: math.max(0, py - 78),
                      width: 148,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: space3, vertical: space2),
                          decoration: BoxDecoration(
                            color: c.surfaceSolid.withValues(alpha: 0.92),
                            border: Border.all(color: c.glassBorder),
                            borderRadius: BorderRadius.circular(radiusSm),
                            boxShadow: [c.shadowGlass],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatMoney(t[shown].income, widget.currency), style: CrText.amountSm(c.ink)),
                              Text(monthLabel(t[shown].month), style: CrText.mono(c.inkFaint, size: 11)),
                              Text('gastos ${formatMoney(t[shown].expense, widget.currency)}', style: CrText.mono(c.inkMuted, size: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.t, this.progress, this.c, this.focus, this.left, this.bottom, this.scale);
  final List<TrendPoint> t;
  final double progress;
  final CrPalette c;
  final int focus;
  final double left, bottom;
  final ({double max, double step}) scale;

  static ({double max, double step}) scaleFor(List<TrendPoint> t) {
    final top = t.fold<double>(0, (a, m) => math.max(a, math.max(m.income, m.expense)));
    if (top <= 0) return (max: 1, step: 0.25);
    final raw = top / 4;
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = (f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5 : 10)))) * exp;
    return (max: nice * (top / nice).ceil(), step: nice);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const top = 16.0;
    final plotH = size.height - bottom - top;
    final plotW = size.width - left - 12;
    double x(int i) => left + (t.length > 1 ? plotW / (t.length - 1) * i : plotW / 2);
    double y(double v) => top + plotH * (1 - (v / scale.max).clamp(0, 1));

    // Cuadrícula punteada y etiquetas del eje
    final grid = Paint()
      ..color = c.hairline
      ..strokeWidth = 1;
    for (var v = 0.0; v <= scale.max + 0.001; v += scale.step) {
      final gy = y(v);
      for (var gx = left; gx < size.width - 12; gx += 6) {
        canvas.drawLine(Offset(gx, gy), Offset(math.min(gx + 2, size.width - 12), gy), grid);
      }
      final tp = TextPainter(
        text: TextSpan(text: formatCompact(v), style: CrText.mono(c.inkFaint, size: 10.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 8, gy - tp.height / 2));
    }
    for (var i = 0; i < t.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: monthLabel(t[i].month), style: CrText.mono(i == focus ? c.ink : c.inkFaint, size: 10.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, size.height - bottom + 8));
    }
    if (t.length < 2) return;

    final inc = [for (var i = 0; i < t.length; i++) Offset(x(i), y(t[i].income))];
    final exp = [for (var i = 0; i < t.length; i++) Offset(x(i), y(t[i].expense))];
    final incPath = monotonePath(inc);
    final expPath = monotonePath(exp);

    // Se dibujan de izquierda a derecha al entrar
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, left + plotW * progress + 6, size.height));

    // Área bajo los ingresos
    final area = Path.from(incPath)
      ..lineTo(inc.last.dx, y(0))
      ..lineTo(inc.first.dx, y(0))
      ..close();
    canvas.drawPath(
      area,
      Paint()..shader = ui.Gradient.linear(Offset(0, top), Offset(0, y(0)), [c.neon.withValues(alpha: 0.30), c.neon.withValues(alpha: 0)]),
    );

    // Gastos: punteado
    for (final m in expPath.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(
          m.extractPath(d, math.min(d + 4, m.length)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = c.inkMuted.withValues(alpha: 0.85),
        );
      }
    }

    // Ingresos: línea con brillo
    canvas.drawPath(
      incPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = c.neonGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      incPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = c.neon,
    );
    canvas.restore();

    // Guía vertical y puntos del mes enfocado
    if (progress > 0.95) {
      final fx = x(focus);
      canvas.drawLine(Offset(fx, top), Offset(fx, y(0)), Paint()..color = c.inkFaint.withValues(alpha: 0.35));
      canvas.drawCircle(exp[focus], 4, Paint()..color = c.inkMuted);
      canvas.drawCircle(inc[focus], 9, Paint()..color = c.neon.withValues(alpha: 0.25));
      canvas.drawCircle(inc[focus], 5, Paint()..color = c.neon);
      canvas.drawCircle(inc[focus], 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) => old.progress != progress || old.focus != focus || old.t != t || old.c != c;
}

/// Reparto del gasto en una barra segmentada (como «Trade 34 % · Hospitality 28 %…»).
class CategoryStrip extends StatelessWidget {
  const CategoryStrip({super.key, required this.rows, required this.names, required this.currency});
  final List<({String? categoryId, double total})> rows;
  final RefData names;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final total = rows.fold<double>(0, (a, r) => a + r.total);
    if (total <= 0) return const SizedBox.shrink();
    final colors = [c.neon, c.chart2, c.chart3, c.chart4, c.amber];
    // Hasta 4 categorías y el resto en «Otras»
    final sorted = [...rows]..sort((a, b) => b.total.compareTo(a.total));
    final segments = <({String name, double total})>[
      for (final r in sorted.take(4)) (name: names.categoryName(r.categoryId), total: r.total),
      if (sorted.length > 4) (name: 'Otras', total: sorted.skip(4).fold<double>(0, (a, r) => a + r.total)),
    ];
    return Semantics(
      label: 'Gasto del mes: ${segments.map((s) => '${s.name} ${(s.total / total * 100).round()} %').join(', ')}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              flex: math.max(1, (segments[i].total / total * 1000).round()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GrowBar(ratio: 1, color: colors[i % colors.length], height: 6, glow: true),
                  const SizedBox(height: space2),
                  if (segments[i].total / total >= 0.08)
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            segments[i].name,
                            style: CrText.mono(c.inkMuted, size: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${(segments[i].total / total * 100).round()} %', style: CrText.mono(c.ink, size: 11)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
