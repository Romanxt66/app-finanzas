import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/category_icon.dart';
import '../ui/deal_card.dart';
import '../ui/glass.dart';
import '../ui/inputs.dart';
import '../ui/motion.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'flow_chart.dart';

/// Lo que se muestra para un periodo de N meses (sumando los resúmenes de cada mes).
class PeriodReport {
  PeriodReport({
    required this.months,
    required this.income,
    required this.expense,
    required this.byCategory,
    required this.trend,
    this.currency,
  });
  final int months;
  final double income, expense;
  final String? currency;

  /// Gasto por categoría en el periodo, de mayor a menor.
  final List<({String? categoryId, double total})> byCategory;
  final List<TrendPoint> trend;

  double get net => income - expense;

  /// Suma los resúmenes mensuales (el más reciente primero).
  static PeriodReport combine(List<Summary> summaries, int months) {
    final byCat = <String?, double>{};
    var income = 0.0, expense = 0.0;
    for (final s in summaries) {
      income += s.income;
      expense += s.expense;
      for (final r in s.byCategory) {
        byCat[r.categoryId] = (byCat[r.categoryId] ?? 0) + r.total;
      }
    }
    final sorted = [for (final e in byCat.entries) (categoryId: e.key, total: e.value)]..sort((a, b) => b.total.compareTo(a.total));
    final trend = summaries.isEmpty ? <TrendPoint>[] : summaries.first.trend.toList();
    return PeriodReport(
      months: months,
      income: income,
      expense: expense,
      byCategory: sorted,
      trend: trend.length > months ? trend.sublist(trend.length - months) : trend,
      currency: summaries.firstOrNull?.currency,
    );
  }
}

/// Análisis: saldo, balance del periodo (1, 3 o 6 meses), flujo de dinero y el gasto por categoría.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _months = 1;

  Future<PeriodReport> _load(Data data) async {
    final now = DateTime.now();
    final months = [for (var i = 0; i < _months; i++) monthStart(DateTime(now.year, now.month - i))];
    final summaries = await Future.wait([for (final m in months) data.summary(m, null)]);
    return PeriodReport.combine(summaries, _months);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ref = context.ref;
    final c = context.c;
    final currency = ref.displayCurrency;
    final balance = ref.accounts.where((a) => a.currency == currency).fold<double>(0, (t, a) => t + a.balance);
    return PageScaffold(
      children: [
        PageHead('Análisis', headline: 'Tus números, *en perspectiva*.'),
        Align(
          alignment: Alignment.centerLeft,
          child: CrSegmented<int>(
            options: const [(1, '1 mes'), (3, '3 meses'), (6, '6 meses')],
            value: _months,
            onChanged: (v) => setState(() => _months = v),
          ),
        ),
        Query<PeriodReport>(
          deps: _months,
          load: () => _load(app.data),
          builder: (context, q) {
            final r = q.data;
            if (r == null) return q.error != null ? ErrorText(q.error) : const Skeleton(lines: 3, height: 120);
            final cur = r.currency ?? currency;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardGrid(
                  minWidth: 150,
                  children: [
                    SummaryTile(icon: 'wallet', color: c.neon, label: 'Saldo de tus cuentas', value: formatMoney(balance, currency)),
                    SummaryTile(
                      icon: r.net >= 0 ? 'up' : 'down',
                      color: r.net >= 0 ? c.positive : c.negative,
                      label: 'Balance ${_months == 1 ? 'del mes' : 'de $_months meses'}',
                      value: formatMoney(r.net, cur, true),
                      note: '${formatMoney(r.income, cur)} entró · ${formatMoney(r.expense, cur)} salió',
                    ),
                  ],
                ),
                const SizedBox(height: space3),
                if (r.trend.length >= 2)
                  Glass(
                    padding: const EdgeInsets.all(space5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle('Flujo de dinero'),
                        const SizedBox(height: space3),
                        FlowChart(trend: r.trend, currency: cur, height: 200),
                      ],
                    ),
                  ),
                if (r.trend.length >= 2) const SizedBox(height: space3),
                _CategoryBreakdown(report: r, ref: ref, currency: cur),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.report, required this.ref, required this.currency});
  final PeriodReport report;
  final RefData ref;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = report.byCategory.where((r) => r.total > 0).toList();
    final total = rows.fold<double>(0, (t, r) => t + r.total);
    return Glass(
      padding: const EdgeInsets.all(space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Gasto por categoría'),
          const SizedBox(height: space2),
          if (rows.isEmpty)
            const CrEmpty('Sin gastos en este periodo.')
          else
            for (final (i, r) in rows.indexed)
              FadeIn(
                delay: Duration(milliseconds: 40 * math.min(i, 8)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: space3),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : Border(top: BorderSide(color: c.hairline)),
                  ),
                  child: Semantics(
                    label:
                        '${ref.categoryName(r.categoryId)}: ${formatMoney(r.total, currency)}, ${(r.total / total * 100).round()} % del gasto',
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        PercentRing(fraction: r.total / total),
                        const SizedBox(width: space3),
                        CategoryGlyph(ref.categoryName(r.categoryId), size: 34),
                        const SizedBox(width: space3),
                        Expanded(
                          child: Text(
                            ref.categoryName(r.categoryId),
                            style: CrText.body(c.ink).copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(formatMoney(-r.total, currency), style: CrText.amountSm(c.ink)),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Anillo pequeño con el porcentaje en el centro (se llena al aparecer).
class PercentRing extends StatelessWidget {
  const PercentRing({super.key, required this.fraction, this.size = 42});
  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = fraction.clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: context.reduceMotion ? f : 0, end: f),
        duration: const Duration(milliseconds: 900),
        curve: crEase,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, c.neon, c.ink.withValues(alpha: 0.08)),
          child: Center(
            child: Text('${(f * 100).round()}%', style: CrText.mono(c.ink, size: 10, weight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track);
  final double value;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 3.5;
    final r = (Offset.zero & size).deflate(w / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}
