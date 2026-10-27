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
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';
import 'flow_chart.dart';
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
                  FlowCard(trend: trend, currency: currency, byCategory: summary?.byCategory ?? const [], names: names),
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
