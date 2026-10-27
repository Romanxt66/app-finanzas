import 'dart:async';

import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/glass.dart';
import '../ui/inputs.dart';
import '../ui/mood_face.dart';
import '../ui/motion.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

const _waits = [(24, '1 día'), (72, '3 días'), (168, '1 semana')];

/// «Faltan 2 d 5 h», «faltan 40 min».
String timeLeft(Duration d) {
  if (d.inMinutes < 1) return 'menos de un minuto';
  final days = d.inDays, hours = d.inHours % 24, minutes = d.inMinutes % 60;
  if (days > 0) return '$days d${hours > 0 ? ' $hours h' : ''}';
  if (hours > 0) return '$hours h${minutes > 0 ? ' $minutes min' : ''}';
  return '$minutes min';
}

/// Sala de espera: aparcar una compra unos días y decidir con la cabeza fría.
class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  // Las cuentas atrás se refrescan solas cada medio minuto
  late final Timer _clock = Timer.periodic(const Duration(seconds: 30), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Query<WaitingRoom>(
      load: () => context.app.data.waitingRoom(),
      builder: (context, q) {
        final r = q.data;
        final now = DateTime.now();
        final pending = r?.items.where((i) => i.status == 'waiting').toList() ?? const <WaitingItem>[];
        final decided = r?.items.where((i) => i.status != 'waiting').toList() ?? const <WaitingItem>[];
        return PageScaffold(
          children: [
            const PageHead(
              'Sala de espera',
              headline: 'Piénsalo *antes* de comprar.',
              lead: 'Deja aquí lo que te tienta. Pasado el plazo decides con la cabeza fría, y lo que no compres suma a tu ahorro.',
            ),
            ErrorText(q.error),
            if (r == null && q.loading) const Skeleton(lines: 2, height: 120) else if (r != null) _NotSpent(room: r),
            const _AddForm(),
            if (pending.isNotEmpty) ...[const SectionTitle('En espera'), for (final item in pending) _PendingCard(item: item, now: now)],
            if (decided.isNotEmpty) ...[
              const SectionTitle('Decididas'),
              GlassList(
                label: 'Decididas',
                children: [
                  for (final (i, item) in decided.indexed)
                    FadeIn(
                      delay: Duration(milliseconds: 40 * (i < 4 ? i : 4)),
                      child: Container(
                        decoration: BoxDecoration(
                          border: i == 0 ? null : Border(top: BorderSide(color: context.c.hairline)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: CrText.body(context.c.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(
                                    item.decidedAt == null ? '' : formatDate(item.decidedAt!.toLocal().toIso8601String().substring(0, 10)),
                                    style: CrText.caption(context.c.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: space3),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatMoney(item.amount, item.currency), style: CrText.amountSm(context.c.ink)),
                                const SizedBox(height: space1),
                                item.status == 'skipped'
                                    ? const CrBadge('no la compraste', tone: Tone.positive)
                                    : const CrBadge('la compraste'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _NotSpent extends StatelessWidget {
  const _NotSpent({required this.room});
  final WaitingRoom room;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = context.isWide;
    final hasSaved = room.notSpent.isNotEmpty;
    final face = MoodFace(
      expression: hasSaved
          ? const FaceExpression(color: Color(0xFFF472D0), smile: 1, mouthOpen: 0.6, eyeHappy: 1, blush: 0.7, sparkle: 1)
          : const FaceExpression(color: Color(0xFFFACC15), smile: 0.3, lid: 0.1),
      size: wide ? 96 : 76,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('lo que no gastaste', style: CrText.overline(c.inkFaint)),
        const SizedBox(height: space2),
        if (hasSaved)
          Wrap(
            spacing: space4,
            children: [
              for (final t in room.notSpent) AnimatedMoney(value: t.total, currency: t.currency, style: CrText.display(c.ink, size: 44)),
            ],
          )
        else
          Text('Aún nada… ¡pero pronto!', style: CrText.display(c.ink, size: 30)),
        const SizedBox(height: space2),
        Text(
          hasSaved
              ? '${room.skipped} compra${room.skipped == 1 ? '' : 's'} descartada${room.skipped == 1 ? '' : 's'} · ${room.bought} hecha${room.bought == 1 ? '' : 's'}'
              : 'Cada compra que decidas no hacer se suma aquí.',
          style: CrText.mono(c.inkFaint, size: 11.5),
        ),
      ],
    );
    return Glass(
      strong: true,
      padding: const EdgeInsets.all(space5),
      child: Row(
        children: [
          face,
          const SizedBox(width: space4),
          Expanded(child: text),
        ],
      ),
    );
  }
}

class _AddForm extends StatefulWidget {
  const _AddForm();

  @override
  State<_AddForm> createState() => _AddFormState();
}

class _AddFormState extends State<_AddForm> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String? _currency;
  int _wait = 72;
  bool _submitted = false;
  bool _busy = false;
  Object? _error;

  String? get _nameError => _submitted && _name.text.trim().isEmpty ? '¿Qué quieres comprar?' : null;
  String? get _amountError => _submitted && parseAmount(_amount.text) == null ? amountError : null;

  Future<void> _save(String currency) async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null || _amountError != null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.app.data.post('/waiting-room', {
        'name': _name.text.trim(),
        'amount': parseAmount(_amount.text),
        'currency': currency,
        'wait_hours': _wait,
      }, 'En espera: te avisamos cuando puedas decidir');
      _name.clear();
      _amount.clear();
      setState(() => _submitted = false);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ref = context.ref;
    final currency = _currency ?? ref.displayCurrency ?? 'EUR';
    final amount = double.tryParse(parseAmount(_amount.text) ?? '');
    final hours = amount == null ? null : lifeHoursNote(amount, ref.hourlyRate);
    return CrCard(
      title: '¿Qué te tienta?',
      child: Stack12(
        children: [
          FormGrid(
            minWidth: 200,
            children: [
              CrTextField(label: 'Qué quieres comprar', controller: _name, error: _nameError, onChanged: (_) => setState(() {})),
              CrTextField(
                label: 'Precio',
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                error: _amountError,
                onChanged: (_) => setState(() {}),
              ),
              CurrencySelect(value: currency, onChanged: (v) => setState(() => _currency = v)),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: space3,
            runSpacing: space3,
            children: [
              Text('Esperar', style: CrText.label(c.inkMuted)),
              CrSegmented<int>(options: _waits, value: _wait, onChanged: (v) => setState(() => _wait = v)),
            ],
          ),
          if (hours != null) FadeIn(child: Text('Te costaría $hours.', style: CrText.serif(c.inkMuted, size: 20))),
          ErrorText(_error),
          Row(
            children: [
              CrButton(
                variant: CrButtonVariant.primary,
                icon: 'target',
                label: 'Dejar en espera',
                onPressed: _busy ? null : () => _save(currency),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.item, required this.now});
  final WaitingItem item;
  final DateTime now;

  Future<void> _decide(BuildContext context, String decision) async {
    final data = context.app.data;
    if (decision == 'bought') {
      await data.post('/waiting-room/${item.id}/decide', {'decision': 'bought'}, 'Marcada como comprada');
      return;
    }
    final goals = (await data.goals()).where((g) => !g.achieved && g.currency == item.currency).toList();
    await data.post('/waiting-room/${item.id}/decide', {
      'decision': 'skipped',
    }, '¡${formatMoney(item.amount, item.currency)} que no gastaste!');
    if (goals.isEmpty || !context.mounted) return;
    await showCrDialog<void>(
      context,
      title: '¿Lo mandas a una meta?',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aparta los ${formatMoney(item.amount, item.currency)} que no gastaste en una de tus metas.',
            style: CrText.body(ctx.c.inkMuted),
          ),
          const SizedBox(height: space4),
          for (final g in goals.take(4)) ...[
            CrButton(
              label: g.name,
              icon: 'chart',
              expand: true,
              onPressed: () async {
                Navigator.pop(ctx);
                await data.post('/goals/${g.id}/contributions', {
                  'amount': item.amount.toStringAsFixed(2),
                  'occurred_on': todayISO(),
                }, 'Aporte a «${g.name}» guardado');
              },
            ),
            const SizedBox(height: space2),
          ],
          CrButton(label: 'Ahora no', variant: CrButtonVariant.ghost, onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ref = context.ref;
    final total = item.readyAt.difference(item.createdAt);
    final left = item.readyAt.difference(now);
    final ready = item.ready || left.inSeconds <= 0;
    final progress = total.inSeconds <= 0 ? 1.0 : (1 - left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final hours = lifeHoursNote(item.amount, ref.hourlyRate);
    return Glass(
      lift: true,
      padding: const EdgeInsets.all(space4),
      borderColor: ready ? c.neon.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: CrText.heading(c.ink)),
                    if (hours != null) Text(hours, style: CrText.mono(c.inkFaint, size: 11.5)),
                  ],
                ),
              ),
              Text(formatMoney(item.amount, item.currency), style: CrText.amount(c.ink)),
            ],
          ),
          const SizedBox(height: space3),
          GrowBar(ratio: progress, color: ready ? c.neon : c.brand, height: 6, glow: ready),
          const SizedBox(height: space2),
          Text(
            ready ? '¡Ya puedes decidir! ¿Todavía lo quieres?' : 'Faltan ${timeLeft(left)} para decidir',
            style: CrText.mono(ready ? c.ink : c.inkMuted, size: 11.5),
          ),
          const SizedBox(height: space3),
          Wrap(
            spacing: space2,
            runSpacing: space2,
            children: [
              CrButton(
                variant: ready ? CrButtonVariant.primary : CrButtonVariant.glass,
                small: true,
                label: 'Ya no la quiero',
                onPressed: () => _decide(context, 'skipped'),
              ),
              if (ready) CrButton(small: true, label: 'La compré', onPressed: () => _decide(context, 'bought')),
              CrButton(
                variant: CrButtonVariant.ghost,
                small: true,
                icon: 'trash',
                tooltip: 'Quitar de la lista',
                onPressed: () async {
                  final ok = await showConfirm(context, title: 'Quitar «${item.name}»', body: 'No contará como gasto ni como ahorro.');
                  if (ok && context.mounted) await context.app.data.delete('/waiting-room/${item.id}', 'Quitada de la lista');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
