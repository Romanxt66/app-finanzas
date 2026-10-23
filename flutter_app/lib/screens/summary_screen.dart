import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _month = firstOfMonth(DateTime.now());
  String? _currency;

  void _go(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return Loader<Summary>(
      key: ValueKey('$_month$_currency'),
      load: () async {
        await app.loadReference();
        return Summary.fromJson(
          await app.api.get(
            '/reports/summary',
            query: {'month': isoDate(_month), 'currency': _currency},
          ) as Map<String, dynamic>,
        );
      },
      builder: (context, s, reload) {
        final total = app.accounts
            .where(
              (a) =>
                  !a.archived &&
                  (s.currency == null || a.currency == s.currency),
            )
            .fold<double>(0, (t, a) => t + a.balance);
        final rate = s.income > 0 ? (s.net / s.income * 100) : null;
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              ScreenTitle('Hola, ${app.user?.fullName.split(' ').first ?? ''}'),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Mes anterior',
                    onPressed: () => _go(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        fmtMonth(_month),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mes siguiente',
                    onPressed: () => _go(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (s.currencies.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final cur in s.currencies)
                        ChoiceChip(
                          label: Text(cur),
                          selected: s.currency == cur,
                          onSelected: (_) => setState(() => _currency = cur),
                        ),
                    ],
                  ),
                ),
              Glass(
                strong: true,
                radius: radiusLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo total', style: TextStyle(color: c.inkMuted)),
                    const SizedBox(height: 4),
                    Amount(total, currency: s.currency, size: 36),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Kpi('Ingresos', s.income, c.positive)),
                  const SizedBox(width: 12),
                  Expanded(child: _Kpi('Gastos', s.expense, c.negative)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Kpi('Balance', s.net, null, signed: true)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Glass(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tasa de ahorro',
                            style: TextStyle(color: c.inkMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rate == null ? '—' : '${rate.round()} %',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SpendDonut(summary: s),
              const SizedBox(height: 12),
              _TrendChart(summary: s),
            ],
          ),
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.color, {this.signed = false});
  final String label;
  final double value;
  final Color? color;
  final bool signed;

  @override
  Widget build(BuildContext context) => Glass(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.c.inkMuted, fontSize: 13)),
        const SizedBox(height: 6),
        Amount(value, size: 20, signed: signed, neutral: !signed),
      ],
    ),
  );
}

const _palette = [
  Color(0xFF34D399),
  Color(0xFFFBBF24),
  Color(0xFF60A5FA),
  Color(0xFFF472B6),
  Color(0xFFA78BFA),
  Color(0xFF94A3B8),
];

class _SpendDonut extends StatelessWidget {
  const _SpendDonut({required this.summary});
  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final rows = [...summary.byCategory]
      ..sort((a, b) => b.total.compareTo(a.total));
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gasto por categoría',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text('Sin gastos este mes.', style: TextStyle(color: c.inkMuted))
          else
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Semantics(
                    label: 'Gráfico de dona del gasto por categoría',
                    child: CustomPaint(
                      painter: _DonutPainter([
                        for (final r in rows) r.total,
                      ], c.hairline),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length && i < 6; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _palette[i % _palette.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  app.categoryName(rows[i].categoryId),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                fmtMoney(rows[i].total),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.track);
  final List<double> values;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawArc(
      rect.deflate(8),
      0,
      math.pi * 2,
      false,
      paint..color = track,
    );
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect.deflate(8),
        start,
        math.max(sweep - 0.03, 0.01),
        false,
        paint..color = _palette[i % _palette.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.track != track;
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.summary});
  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = summary.trend;
    final maxV = t.fold<double>(
      1,
      (m, e) => math.max(m, math.max(e.income, e.expense)),
    );
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tendencia',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              _Dot(c.positive, 'Ingresos'),
              const SizedBox(width: 12),
              _Dot(c.negative, 'Gastos'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in t)
                  Expanded(
                    child: Semantics(
                      label:
                          '${fmtMonth(m.month)}: ingresos ${fmtMoney(m.income)}, gastos ${fmtMoney(m.expense)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _Bar(m.income / maxV, c.positive),
                                const SizedBox(width: 3),
                                _Bar(m.expense / maxV, c.negative),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fmtMonth(m.month).substring(0, 3),
                            style: TextStyle(fontSize: 11, color: c.inkFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: fraction.clamp(0.02, 1),
    child: Container(
      width: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: context.c.inkMuted)),
    ],
  );
}
