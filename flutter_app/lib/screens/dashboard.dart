import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/icons.dart';
import '../ui/inputs.dart';
import '../ui/motion.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';
import 'insights.dart';

/// Variación % frente al mes anterior; null si no hay base de comparación.
double? change(double current, double? previous) => (previous != null && previous != 0) ? (current - previous) / previous * 100 : null;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _month = monthStart();
  String? _chosenCurrency;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ref = context.ref;
    return Query<Summary>(
      deps: '$_month$_chosenCurrency',
      load: () => app.data.summary(_month, _chosenCurrency),
      builder: (context, sq) {
        final summary = sq.data;
        final currency = summary?.currency;
        final currencies = summary?.currencies ?? const <String>[];
        return Query<TransactionPage>(
          load: () => app.data.transactions({'limit': 5, 'offset': 0}),
          builder: (context, tq) => Query<List<Recurring>>(
            load: () => app.data.recurring(),
            builder: (context, rq) {
              final recent = tq.data;
              final upcoming = ([...?rq.data]..retainWhere((r) => r.active))..sort((a, b) => a.nextDate.compareTo(b.nextDate));
              final trend = summary?.trend ?? const [];
              final prev = trend.length > 1 ? trend[trend.length - 2] : null;
              final income = summary?.income ?? 0;
              final expense = summary?.expense ?? 0;
              final total = ref.accounts.where((a) => currency == null || a.currency == currency).fold<double>(0, (t, a) => t + a.balance);
              final savingsRate = income > 0 ? ((income - expense) / income * 100).round() : null;
              final expenseTotal = (summary?.byCategory ?? const []).fold<double>(0, (a, b) => a + b.total);
              final names = ref;
              final liveCurrencyOf = ref.currencyOf;
              final rate = ref.hourlyRate;
              final showGuide =
                  recent != null && ref.loaded && !(ref.allAccounts.isNotEmpty && ref.categories.isNotEmpty && recent.total > 0);

              return PageScaffold(
                children: [
                  PageHead(
                    'Resumen',
                    headline: 'Tu dinero, *claro*.',
                    actions: [
                      if (currencies.length > 1)
                        CrSegmented<String>(
                          options: [for (final cur in currencies) (cur, cur)],
                          value: currency ?? currencies.first,
                          onChanged: (v) => setState(() => _chosenCurrency = v),
                        ),
                      SizedBox(
                        width: 200,
                        child: CrMonthField(
                          label: 'Mes',
                          month: parseIso(_month),
                          onChanged: (d) => setState(() => _month = monthStart(d)),
                        ),
                      ),
                    ],
                  ),
                  if (showGuide)
                    _GettingStarted(
                      hasAccounts: ref.allAccounts.isNotEmpty,
                      hasCategories: ref.categories.isNotEmpty,
                      hasTransactions: (recent.total) > 0,
                    ),
                  FinanceMoodCard(month: _month, income: income, expense: expense, balance: total),
                  BalanceCard(
                    label: 'Saldo total',
                    value: total,
                    currency: currency,
                    note: ref.accounts.isEmpty
                        ? null
                        : '${ref.accounts.length} cuenta${ref.accounts.length == 1 ? '' : 's'} activa${ref.accounts.length == 1 ? '' : 's'}',
                    trend: trend.length > 1 ? [for (final m in trend) m.income - m.expense] : null,
                    trendLabel: 'Neto de los últimos meses',
                    hidden: app.balanceHidden,
                    onToggleHidden: app.toggleBalanceHidden,
                  ),
                  const DailyAllowanceCard(),
                  _KpiGrid(
                    children: [
                      StatTile(
                        label: 'Ingresos',
                        value: income,
                        currency: currency,
                        delta: change(income, prev?.income),
                        icon: 'salary',
                        tone: Tone.brand,
                      ),
                      StatTile(
                        label: 'Gastos',
                        value: expense,
                        currency: currency,
                        delta: change(expense, prev?.expense),
                        invertDelta: true,
                        icon: 'wallet',
                        tone: Tone.amber,
                      ),
                      StatTile(
                        label: 'Neto del mes',
                        value: income - expense,
                        currency: currency,
                        icon: 'chart',
                        note: savingsRate == null
                            ? null
                            : (savingsRate >= 0
                                  ? 'Ahorraste el $savingsRate % de tus ingresos'
                                  : 'Gastaste ${savingsRate.abs()} % más de lo que ingresó'),
                      ),
                    ],
                  ),
                  GridCols(
                    children: [
                      CrCard(
                        title: 'Tendencia',
                        meta: '${trend.length} meses',
                        child: _TrendChart(trend: trend, currency: currency),
                      ),
                      CrCard(
                        title: 'Gasto por categoría',
                        child: (summary == null || summary.byCategory.isEmpty)
                            ? const CrEmpty('Sin gastos este mes.')
                            : _CategoryDonut(rows: summary.byCategory, total: expenseTotal, names: names, currency: currency),
                      ),
                    ],
                  ),
                  GridCols(
                    children: [
                      LifeHoursCard(month: _month),
                      const GhostTeaser(),
                    ],
                  ),
                  const GridCols(children: [PersonalInflationCard(), SpendingMoodCard()]),
                  const WaitingTeaser(),
                  if (upcoming.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle('Próximos recurrentes'),
                        GlassList(
                          label: 'Próximos recurrentes',
                          children: [
                            for (var i = 0; i < math.min(3, upcoming.length); i++)
                              TransactionRow(
                                first: i == 0,
                                index: i,
                                kind: txKind(upcoming[i].type),
                                title: upcoming[i].description.isNotEmpty
                                    ? upcoming[i].description
                                    : (upcoming[i].categoryId != null ? names.categoryName(upcoming[i].categoryId) : 'Recurrente'),
                                detail: '${formatDate(upcoming[i].nextDate)} · ${cadenceLabels[upcoming[i].frequency]}',
                                amount: upcoming[i].amount,
                                currency: liveCurrencyOf(upcoming[i].accountId),
                              ),
                          ],
                        ),
                      ],
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('Movimientos recientes'),
                      if (recent == null || recent.items.isEmpty)
                        const CrCard(child: CrEmpty('Aún no hay movimientos.'))
                      else
                        GlassList(
                          label: 'Movimientos recientes',
                          children: [
                            for (var i = 0; i < recent.items.length; i++)
                              TransactionRow(
                                first: i == 0,
                                index: i,
                                kind: txKind(recent.items[i].type),
                                title: recent.items[i].description.isNotEmpty
                                    ? recent.items[i].description
                                    : (recent.items[i].categoryId != null
                                          ? names.categoryName(recent.items[i].categoryId)
                                          : const {
                                              'income': 'Ingreso',
                                              'expense': 'Gasto',
                                              'transfer': 'Transferencia',
                                            }[recent.items[i].type]!),
                                detail: [
                                  formatDate(recent.items[i].occurredOn),
                                  if (recent.items[i].type == 'expense') lifeHoursNote(recent.items[i].amount, rate),
                                ].whereType<String>().join(' · '),
                                amount: recent.items[i].amount,
                                currency: liveCurrencyOf(recent.items[i].accountId),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: space3), Expanded(child: children[i])],
          ],
        ),
      );
    }
    // Dos columnas; el último, si queda impar, ocupa todo el ancho
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final pair = children.skip(i).take(2).toList();
      rows.add(
        pair.length == 2
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: pair[0]),
                    const SizedBox(width: space3),
                    Expanded(child: pair[1]),
                  ],
                ),
              )
            : pair[0],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: space3), rows[i]],
      ],
    );
  }
}

/// Guía de primeros pasos: desaparece sola cuando ya hay cuenta, categorías y un movimiento.
class _GettingStarted extends StatelessWidget {
  const _GettingStarted({required this.hasAccounts, required this.hasCategories, required this.hasTransactions});
  final bool hasAccounts, hasCategories, hasTransactions;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final steps = [
      ('/accounts', 'Crea tu primera cuenta', hasAccounts, 'wallet'),
      ('/categories', 'Define tus categorías', hasCategories, 'tag'),
      ('/transactions', 'Registra tu primer movimiento', hasTransactions, 'plus'),
    ];
    final ink = c.onNeon;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.neon,
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: [BoxShadow(color: c.neonGlow, blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('empieza aquí', style: CrText.mono(ink.withValues(alpha: 0.7), size: 12)),
          const SizedBox(height: space2),
          CrHeadline('Tres pasos y tu mes *se ordena solo*.', size: context.isWide ? 30 : 24, color: ink),
          const SizedBox(height: space4),
          for (final s in steps) ...[_StepRow(to: s.$1, label: s.$2, done: s.$3, icon: s.$4), const SizedBox(height: space2)],
          const SizedBox(height: space1),
          Text.rich(
            TextSpan(
              style: CrText.caption(ink.withValues(alpha: 0.75)),
              children: [
                const TextSpan(text: '¿Vienes de otra app? Puedes '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.go('/import'),
                      child: Text(
                        'importar el CSV de tu banco',
                        style: CrText.caption(ink).copyWith(decoration: TextDecoration.underline, decorationColor: ink),
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatefulWidget {
  const _StepRow({required this.to, required this.label, required this.done, required this.icon});
  final String to, label, icon;
  final bool done;

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: '${widget.label} (${widget.done ? 'hecho' : 'pendiente'})',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => context.go(widget.to),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(space3),
            decoration: BoxDecoration(
              color: Color.lerp(c.onNeon, c.neon, _hover ? 0.12 : 0.0)!.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(radiusPill),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: widget.done ? c.neon : Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                  child: Center(child: CrIcon(widget.done ? 'check' : widget.icon, size: 16, color: widget.done ? c.onNeon : Colors.white)),
                ),
                const SizedBox(width: space3),
                Expanded(
                  child: Text(
                    widget.label,
                    style: CrText.body(Colors.white.withValues(alpha: widget.done ? 0.55 : 1)).copyWith(
                      decoration: widget.done ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white54,
                    ),
                  ),
                ),
                AnimatedSlide(
                  offset: _hover && !context.reduceMotion ? const Offset(0.2, 0) : Offset.zero,
                  duration: const Duration(milliseconds: 250),
                  child: const CrIcon('arrow', size: 16, color: Colors.white70),
                ),
                const SizedBox(width: space1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.rows, required this.total, required this.names, required this.currency});
  final List<({String? categoryId, double total})> rows;
  final double total;
  final RefData names;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colors = donutColors(c);
    final label =
        'Distribución del gasto: ${rows.take(3).map((r) => '${names.categoryName(r.categoryId)} ${(total > 0 ? r.total / total * 100 : 0).round()} %').join(', ')}';
    final list = Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: space2),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: space2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[i % 4].withValues(alpha: i < 4 ? 1 : 0.55),
                  ),
                ),
                Expanded(
                  child: Text(
                    names.categoryName(rows[i].categoryId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CrText.body(c.ink),
                  ),
                ),
                const SizedBox(width: space2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: formatMoney(rows[i].total, currency), style: CrText.amountSm(c.ink)),
                      TextSpan(text: '  ${(total > 0 ? rows[i].total / total * 100 : 0).round()} %', style: CrText.mono(c.inkFaint, size: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final donut = Donut(values: [for (final r in rows) r.total], label: label);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 132 + space5 + 180) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              donut,
              const SizedBox(width: space5),
              Expanded(child: list),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: donut),
            const SizedBox(height: space4),
            list,
          ],
        );
      },
    );
  }
}

/// Barras de ingresos y gastos de los últimos meses, con cuadrícula, ejes y tooltip al pasar el puntero.
class _TrendChart extends StatefulWidget {
  const _TrendChart({required this.trend, required this.currency});
  final List<({String month, double income, double expense})> trend;
  final String? currency;

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = widget.trend;
    Widget legend(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(text, style: CrText.mono(c.inkMuted, size: 11)),
      ],
    );
    return Semantics(
      label: 'Tendencia de ingresos y gastos de los últimos meses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [legend(c.neon, 'ingresos'), const SizedBox(width: space4), legend(c.inkMuted, 'gastos')]),
          const SizedBox(height: space2),
          _chart(context, c, t),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context, CrPalette c, List<({String month, double income, double expense})> t) {
    return Semantics(
      child: SizedBox(
        height: 240,
        child: LayoutBuilder(
          builder: (context, box) {
            const left = 44.0;
            const bottom = 28.0;
            final plotW = box.maxWidth - left;
            final slot = t.isEmpty ? 1.0 : plotW / t.length;
            return MouseRegion(
              onHover: (e) {
                final i = ((e.localPosition.dx - left) / slot).floor();
                setState(() => _hover = (i >= 0 && i < t.length && e.localPosition.dx >= left) ? i : null);
              },
              onExit: (_) => setState(() => _hover = null),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
                      duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
                      curve: crEase,
                      builder: (context, v, _) => CustomPaint(painter: _TrendPainter(t, v, c, _hover, left, bottom)),
                    ),
                  ),
                  if (_hover != null)
                    Positioned(
                      left: (left + slot * _hover! + slot / 2 - 90).clamp(0, math.max(0, box.maxWidth - 180)),
                      top: 8,
                      width: 180,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(space3),
                          decoration: BoxDecoration(
                            color: c.surfaceSolid,
                            border: Border.all(color: c.glassBorder),
                            borderRadius: BorderRadius.circular(radiusSm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(monthLabel(t[_hover!].month), style: CrText.label(c.ink)),
                              Text('ingresos  ${formatMoney(t[_hover!].income, widget.currency)}', style: CrText.mono(c.neon, size: 11.5)),
                              Text('gastos    ${formatMoney(t[_hover!].expense, widget.currency)}', style: CrText.mono(c.inkMuted, size: 11.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.t, this.progress, this.c, this.hover, this.left, this.bottom);
  final List<({String month, double income, double expense})> t;
  final double progress;
  final CrPalette c;
  final int? hover;
  final double left, bottom;

  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final exp = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / exp;
    final nice = f <= 1
        ? 1
        : f <= 1.5
        ? 1.5
        : f <= 2
        ? 2
        : f <= 3
        ? 3
        : f <= 5
        ? 5
        : 10;
    return nice * exp;
  }

  void _text(Canvas canvas, String text, Offset at, {TextAlign align = TextAlign.left, double? maxWidth}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: CrText.mono(c.inkFaint, size: 11),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth ?? 100);
    final dx = align == TextAlign.right ? at.dx - tp.width : (align == TextAlign.center ? at.dx - tp.width / 2 : at.dx);
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = t.fold<double>(0, (m, e) => math.max(m, math.max(e.income, e.expense)));
    final step = _niceStep(maxV / 4);
    final top = step * 4;
    final plotH = size.height - bottom - 8;
    final grid = Paint()
      ..color = c.hairline
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 8 + plotH - plotH * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      _text(canvas, i == 0 ? '0' : formatCompact(step * i), Offset(left - 8, y), align: TextAlign.right);
    }
    if (t.isEmpty) return;
    final slot = (size.width - left) / t.length;
    for (var i = 0; i < t.length; i++) {
      final cx = left + slot * i + slot / 2;
      if (hover == i) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(left + slot * i + 2, 8, slot - 4, plotH), const Radius.circular(10)),
          Paint()..color = c.glass,
        );
      }
      final barW = math.min(24.0, slot * 0.30);
      final depth = barW * 0.55;
      final lit = hover == i || (hover == null && i == t.length - 1);
      final baseY = 8 + plotH;

      // Prisma isométrico: cara frontal, lateral y tapa (como las barras del diseño «Relay»)
      void prism(double v, double x, Color front, Color side, Color cap, {bool glow = false}) {
        final h = top > 0 ? plotH * (v / top) * progress : 0.0;
        if (h <= 0.5) return;
        final dx = depth * 0.9, dy = depth * 0.5;
        final y = baseY - h;
        if (glow) {
          canvas.drawRect(
            Rect.fromLTWH(x - 4, y - dy, barW + dx + 8, h + dy),
            Paint()
              ..color = cap.withValues(alpha: 0.28)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
          );
        }
        canvas.drawRect(
          Rect.fromLTWH(x, y, barW, h),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [front, front.withValues(alpha: front.a * 0.35)],
            ).createShader(Rect.fromLTWH(x, y, barW, h)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(x + barW, y)
            ..lineTo(x + barW + dx, y - dy)
            ..lineTo(x + barW + dx, baseY - dy)
            ..lineTo(x + barW, baseY)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [side, side.withValues(alpha: side.a * 0.3)],
            ).createShader(Rect.fromLTWH(x + barW, y - dy, dx, h + dy)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x + dx, y - dy)
            ..lineTo(x + barW + dx, y - dy)
            ..lineTo(x + barW, y)
            ..close(),
          Paint()..color = cap,
        );
      }

      final neon = c.neon;
      final slate = c.inkMuted;
      prism(
        t[i].income,
        cx - barW - depth * 0.45 - 2,
        neon.withValues(alpha: lit ? 0.85 : 0.45),
        Color.lerp(neon, Colors.black, 0.45)!.withValues(alpha: lit ? 0.9 : 0.5),
        lit ? Color.lerp(neon, Colors.white, 0.35)! : neon.withValues(alpha: 0.7),
        glow: lit,
      );
      prism(
        t[i].expense,
        cx + 2,
        slate.withValues(alpha: lit ? 0.55 : 0.32),
        Color.lerp(slate, Colors.black, 0.5)!.withValues(alpha: lit ? 0.7 : 0.4),
        Color.lerp(slate, Colors.white, lit ? 0.55 : 0.3)!.withValues(alpha: lit ? 0.95 : 0.7),
      );
      _text(canvas, monthLabel(t[i].month), Offset(cx, size.height - bottom / 2 + 4), align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.progress != progress || old.t != t || old.hover != hover || old.c != c;
}
