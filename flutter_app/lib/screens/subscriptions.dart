import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

/// Cobros recurrentes detectados en tus gastos, con los que aún no registraste como recurrentes.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Query<GhostReport>(
      load: () => context.app.data.ghost(),
      builder: (context, q) {
        final data = q.data;
        final ghosts = data?.subscriptions.where((s) => !s.tracked).toList() ?? const <Subscription>[];
        final tracked = data?.subscriptions.where((s) => s.tracked).toList() ?? const <Subscription>[];
        return PageScaffold(
          children: [
            PageHead('Suscripciones'),
            ErrorText(q.error),
            if (q.loading)
              const Skeleton(lines: 3, height: 72)
            else if (data == null || (data.subscriptions.isEmpty && data.alerts.isEmpty))
              const CrCard(child: CrEmpty('Aún no detectamos cobros recurrentes. Con unos meses de gastos registrados, aparecerán aquí.'))
            else ...[
              if (data.alerts.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Alertas'),
                    GlassList(
                      label: 'Alertas',
                      children: [
                        for (var i = 0; i < data.alerts.length; i++)
                          Container(
                            decoration: BoxDecoration(
                              border: i == 0 ? null : Border(top: BorderSide(color: c.hairline)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CrChip(alertIcons[data.alerts[i].kind] ?? 'tag', tone: Tone.amber),
                                const SizedBox(width: space3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(alertText(data.alerts[i]), style: CrText.body(c.ink)),
                                      Text(formatDate(data.alerts[i].date), style: CrText.caption(c.inkMuted)),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    'Sin registrar',
                    trailing: data.untrackedMonthly.isEmpty
                        ? null
                        : Text(
                            '≈ ${data.untrackedMonthly.map((t) => formatMoney(t.total, t.currency)).join(' + ')} al mes',
                            style: CrText.label(c.inkMuted),
                          ),
                  ),
                  if (ghosts.isEmpty)
                    const CrCard(child: CrEmpty('No hay cobros fantasma. Todo lo recurrente ya está registrado.'))
                  else
                    _SubscriptionList(items: ghosts, label: 'Cobros sin registrar'),
                  if (ghosts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(space2, space3, space2, 0),
                      child: Text.rich(
                        TextSpan(
                          style: CrText.caption(c.inkMuted),
                          children: [
                            const TextSpan(text: 'Regístralos en '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => context.go('/recurring'),
                                  child: Text('Recurrentes', style: CrText.caption(c.brand).copyWith(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' para que cuenten en tu «Disponible hoy» y te avisemos de sus cambios.'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (tracked.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Ya registradas'),
                    _SubscriptionList(items: tracked, label: 'Cobros ya registrados'),
                  ],
                ),
            ],
          ],
        );
      },
    );
  }
}

class _SubscriptionList extends StatelessWidget {
  const _SubscriptionList({required this.items, required this.label});
  final List<Subscription> items;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GlassList(
      label: label,
      children: [
        for (var i = 0; i < items.length; i++)
          RowSplit(
            first: i == 0,
            index: i,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CrChip('swap', tone: Tone.brand),
                  const SizedBox(width: space3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: CrText.body(c.ink)),
                        Text(
                          '${cadenceLabels[items[i].cadence]} · próximo ≈ ${formatDate(items[i].nextExpected)}',
                          style: CrText.caption(c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatMoney(items[i].lastAmount, items[i].currency), style: CrText.amountSm(c.ink)),
                      Text('≈ ${formatMoney(items[i].monthlyCost, items[i].currency)}/mes', style: CrText.caption(c.inkMuted)),
                    ],
                  ),
                  const SizedBox(width: space3),
                  CrBadge(items[i].tracked ? 'Registrada' : 'Sin registrar', tone: items[i].tracked ? Tone.positive : Tone.warning),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
