import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../core/data.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/glass.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const cadenceLabels = {'weekly': 'cada semana', 'monthly': 'cada mes', 'yearly': 'cada año'};
const alertIcons = {'price_increase': 'up', 'duplicate': 'swap', 'trial_converted': 'tag'};

String alertText(GhostAlert a) {
  final amount = formatMoney(a.amount, a.currency);
  final previous = a.previousAmount == null ? '' : formatMoney(a.previousAmount!, a.currency);
  return switch (a.kind) {
    'price_increase' => '${a.name} subió de $previous a $amount (+${formatPercent(a.changePercent ?? 0)} %).',
    'duplicate' => 'Posible cobro duplicado de ${a.name}: $amount dos veces en pocos días.',
    _ => '${a.name}: la prueba de $previous pasó a un cobro de $amount.',
  };
}

/// Formulario de un solo campo en un diálogo (renombrar, editar un monto…).
Future<void> showFieldDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
  required Future<void> Function(String value) onSubmit,
  String? Function(String value)? validate,
  bool decimal = false,
}) {
  return showCrDialog<void>(
    context,
    title: title,
    builder: (ctx) => _FieldForm(label: label, initial: initial, validate: validate, decimal: decimal, onSubmit: onSubmit),
  );
}

class _FieldForm extends StatefulWidget {
  const _FieldForm({required this.label, required this.initial, required this.onSubmit, this.validate, this.decimal = false});
  final String label, initial;
  final Future<void> Function(String) onSubmit;
  final String? Function(String)? validate;
  final bool decimal;

  @override
  State<_FieldForm> createState() => _FieldFormState();
}

class _FieldFormState extends State<_FieldForm> {
  late final _c = TextEditingController(text: widget.initial);
  String? _problem;
  Object? _error;
  bool _busy = false;

  Future<void> _submit() async {
    final v = _c.text.trim();
    final problem = widget.validate != null ? widget.validate!(v) : (v.isEmpty ? 'Requerido' : null);
    setState(() {
      _problem = problem;
      _error = null;
    });
    if (problem != null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(v);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack12(
    children: [
      CrTextField(
        label: widget.label,
        controller: _c,
        autofocus: true,
        error: _problem,
        keyboardType: widget.decimal ? const TextInputType.numberWithOptions(decimal: true) : null,
        onSubmitted: (_) => _submit(),
      ),
      ErrorText(_error),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CrButton(label: 'Cancelar', variant: CrButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
          const SizedBox(width: space2),
          CrButton(label: 'Guardar', variant: CrButtonVariant.primary, onPressed: _busy ? null : _submit),
        ],
      ),
    ],
  );
}

/// Selector de moneda alimentado por la lista de la API.
class CurrencySelect extends StatelessWidget {
  const CurrencySelect({super.key, required this.value, required this.onChanged, this.error, this.label = 'Moneda'});
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;
  final String label;

  @override
  Widget build(BuildContext context) {
    final codes = context.ref.currencies;
    return CrSelect<String>(
      label: label,
      value: value,
      error: error,
      options: [('', 'Selecciona…'), for (final code in codes) (code, currencyLabel(code))],
      onChanged: onChanged,
    );
  }
}

const _newCategory = '__new__';
const _suggested = 'suggested:';

/// Categorías propias, sugeridas (se crean al elegirlas) y «Nueva categoría…» sin salir del formulario.
class CategorySelect extends StatelessWidget {
  const CategorySelect({
    super.key,
    required this.kind,
    required this.value,
    required this.onChanged,
    this.label = 'Categoría',
    this.emptyLabel = 'Sin categoría',
    this.error,
  });
  final String kind;
  final String value;
  final ValueChanged<String> onChanged;
  final String label, emptyLabel;
  final String? error;

  Future<void> _create(BuildContext context, String name) async {
    final app = context.app;
    final mine = context.ref.categories.where((c) => c.kind == kind);
    final existing = mine.where((c) => c.name.toLowerCase() == name.toLowerCase()).firstOrNull;
    if (existing != null) {
      onChanged(existing.id);
      return;
    }
    final json = await app.api.post('/categories', body: {'name': name, 'kind': kind}) as Map<String, dynamic>;
    app.onToast?.call('Categoría creada');
    app.invalidate();
    onChanged(json['id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    final mine = context.ref.categories.where((c) => c.kind == kind).toList();
    final taken = mine.map((c) => c.name.toLowerCase()).toSet();
    return Query<CategorySuggestions>(
      load: () => context.app.data.categorySuggestions(),
      builder: (context, q) {
        final offered =
            (kind == 'income' ? q.data?.income : q.data?.expense)?.where((n) => !taken.contains(n.toLowerCase())).toList() ??
            const <String>[];
        return CrSelect<String>(
          label: label,
          value: value,
          error: error,
          options: [
            ('', emptyLabel),
            for (final c in mine) (c.id, c.name),
            for (final n in offered) ('$_suggested$n', '$n · sugerida'),
            (_newCategory, '＋ Nueva categoría…'),
          ],
          onChanged: (v) async {
            if (v == _newCategory) {
              await showFieldDialog(
                context,
                title: 'Nueva categoría',
                label: 'Nombre de la categoría',
                initial: '',
                onSubmit: (name) => _create(context, name),
              );
            } else if (v.startsWith(_suggested)) {
              try {
                await _create(context, v.substring(_suggested.length));
              } on ApiError catch (e) {
                if (context.mounted) {
                  await showCrDialog<void>(context, title: 'No se pudo crear', builder: (_) => Text(e.message));
                }
              }
            } else {
              onChanged(v);
            }
          },
        );
      },
    );
  }
}

/// «Disponible hoy»: lo que queda del mes repartido entre los días que faltan.
class DailyAllowanceCard extends StatelessWidget {
  const DailyAllowanceCard({super.key});

  static const _messages = {
    'ok': 'Vas dentro de tu ritmo.',
    'tight': 'Hoy ya superaste lo que te tocaba.',
    'over': 'No queda margen para el resto del mes.',
    'no_data': 'Define un presupuesto del mes o registra tus ingresos para calcularlo.',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Query<DailyAllowance?>(
      load: () => context.app.data.allowance(),
      builder: (context, q) {
        if (q.loading) return const Skeleton(lines: 1, height: 160);
        final d = q.data;
        if (d == null) return const SizedBox.shrink();
        final ratio = d.allowanceToday > 0 ? d.spentToday / d.allowanceToday : (d.spentToday > 0 ? 1.0 : 0.0);
        final danger = d.status == 'tight' || d.status == 'over';
        final basis = d.basis == 'budget' ? 'Según tu presupuesto del mes' : 'Según tus ingresos del mes';
        final wide = context.isWide;
        final gauge = SizedBox(
          width: wide ? 120 : 96,
          height: wide ? 120 : 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Gauge(ratio: ratio, danger: danger, size: wide ? 120 : 96),
              Text('${(ratio.clamp(0, 9.99) * 100).round()}%', style: CrText.display(c.ink, size: wide ? 24 : 20)),
            ],
          ),
        );
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(header: true, child: Text('disponible hoy', style: CrText.overline(c.inkFaint))),
            const SizedBox(height: space2),
            AnimatedMoney(value: d.leftToday, currency: d.currency, style: CrText.display(danger ? c.negative : c.ink, size: 44)),
            const SizedBox(height: space2),
            Text(_messages[d.status] ?? '', style: CrText.body(c.ink)),
            if (d.status != 'no_data') ...[
              const SizedBox(height: space2),
              Wrap(
                spacing: space5,
                runSpacing: space2,
                children: [
                  _Fact('Te tocaban hoy', formatMoney(d.allowanceToday, d.currency)),
                  _Fact('Quedan ${d.daysRemaining} días', '≈ ${formatMoney(d.averagePerDay, d.currency)}/día'),
                  if (d.pendingCommitted > 0) _Fact('Ya comprometido', formatMoney(d.pendingCommitted, d.currency)),
                ],
              ),
              const SizedBox(height: space2),
              Text('$basis${d.patternUsed ? ' · ajustado a tus hábitos por día de la semana' : ''}'.toLowerCase(), style: CrText.mono(c.inkFaint, size: 11.5)),
            ],
          ],
        );
        return Glass(
          strong: true,
          padding: const EdgeInsets.all(space5),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    gauge,
                    const SizedBox(width: space5),
                    Expanded(child: body),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    gauge,
                    const SizedBox(height: space5),
                    body,
                  ],
                ),
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toLowerCase(), style: CrText.mono(c.inkFaint, size: 11.5)),
        Text(value, style: CrText.amountSm(c.ink)),
      ],
    );
  }
}

/// Cuánto trabajo cuestan los gastos del mes, y el valor de la hora que lo calcula.
class LifeHoursCard extends StatelessWidget {
  const LifeHoursCard({super.key, required this.month});
  final String month;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    final ref = context.ref;
    return Query<LifeProfile?>(
      load: () => app.data.lifeProfile(),
      builder: (context, pq) {
        final profile = pq.data;
        return Query<LifeMonth?>(
          deps: '$month${profile != null}',
          enabled: profile != null,
          load: () => app.data.lifeMonth(month),
          builder: (context, mq) {
            final top = (mq.data?.byCategory ?? const []).take(3).toList();
            return CrCard(
              title: 'Horas de vida',
              action: pq.loading
                  ? null
                  : CrButton(
                      variant: CrButtonVariant.ghost,
                      small: true,
                      icon: 'edit',
                      label: profile != null ? 'Editar' : 'Configurar',
                      onPressed: () => showRateDialog(context, profile),
                    ),
              child: pq.loading
                  ? const Skeleton(lines: 2, height: 28)
                  : profile == null
                  ? const CrEmpty('Descubre cuántas horas de trabajo cuesta cada gasto. Indica tu ingreso para empezar.')
                  : Stack12(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatHours(mq.data?.totalHours ?? 0), style: CrText.display(c.ink, size: 44)),
                            Text('de trabajo se fueron en gastos este mes', style: CrText.label(c.inkMuted)),
                          ],
                        ),
                        if (top.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < top.length; i++)
                                RowSplit(
                                  first: i == 0,
                                  index: i,
                                  children: [
                                    Text(ref.categoryName(top[i].categoryId), style: CrText.body(c.ink)),
                                    Text(formatHours(top[i].hours), style: CrText.amountSm(c.ink)),
                                  ],
                                ),
                            ],
                          ),
                        Text('tu hora vale ${formatMoney(profile.hourlyRate, ref.displayCurrency)}', style: CrText.mono(c.inkFaint, size: 11.5)),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

Future<void> showRateDialog(BuildContext context, LifeProfile? profile) => showCrDialog<void>(
  context,
  title: '¿Cuánto vale tu hora?',
  builder: (_) => _RateForm(profile: profile),
);

class _RateForm extends StatefulWidget {
  const _RateForm({required this.profile});
  final LifeProfile? profile;

  @override
  State<_RateForm> createState() => _RateFormState();
}

class _RateFormState extends State<_RateForm> {
  late final _income = TextEditingController(text: widget.profile?.monthlyNetIncome ?? '');
  late final _weekly = TextEditingController(text: widget.profile?.weeklyHours ?? '40');
  bool _submitted = false;
  bool _busy = false;
  Object? _error;

  String? get _incomeError => _submitted && parseAmount(_income.text) == null ? amountError : null;
  String? get _weeklyError {
    if (!_submitted) return null;
    final v = parseAmount(_weekly.text);
    if (v == null) return 'Número válido';
    final n = double.parse(v);
    return n > 0 && n <= 168 ? null : 'Entre 1 y 168 horas';
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_incomeError != null || _weeklyError != null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.app.data.put('/life-hours/profile', {
        'monthly_net_income': parseAmount(_income.text),
        'weekly_hours': parseAmount(_weekly.text),
      }, 'Valor de tu hora guardado');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _income.dispose();
    _weekly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rate = hourlyRate(double.tryParse(parseAmount(_income.text) ?? '') ?? 0, double.tryParse(parseAmount(_weekly.text) ?? '') ?? 0);
    return Stack12(
      children: [
        CrTextField(
          label: 'Ingreso neto mensual',
          controller: _income,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: _incomeError,
          onChanged: (_) => setState(() {}),
        ),
        CrTextField(
          label: 'Horas de trabajo por semana',
          controller: _weekly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: _weeklyError,
          onChanged: (_) => setState(() {}),
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            rate != null
                ? 'Tu hora vale ≈ ${formatMoney(rate, context.ref.displayCurrency)}'
                : 'Escribe tu ingreso para ver el valor de tu hora.',
            style: CrText.label(c.inkMuted),
          ),
        ),
        ErrorText(_error),
        Wrap(
          spacing: space3,
          children: [
            CrButton(label: 'Guardar', variant: CrButtonVariant.primary, onPressed: _busy ? null : _save),
            CrButton(label: 'Cancelar', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ],
    );
  }
}

/// Aviso del resumen: solo aparece si hay cobros sin registrar o alertas que revisar.
class GhostTeaser extends StatelessWidget {
  const GhostTeaser({super.key});

  @override
  Widget build(BuildContext context) => Query<GhostReport>(
    load: () => context.app.data.ghost(),
    builder: (context, q) {
      final data = q.data;
      if (data == null) return const SizedBox.shrink();
      final ghosts = data.subscriptions.where((s) => !s.tracked).toList();
      if (ghosts.isEmpty && data.alerts.isEmpty) return const SizedBox.shrink();
      final c = context.c;
      final totals = data.untrackedMonthly.map((t) => formatMoney(t.total, t.currency)).join(' + ');
      return CrCard(
        title: 'Suscripciones fantasma',
        child: Stack12(
          children: [
            if (ghosts.isNotEmpty)
              Text(
                '${ghosts.length == 1 ? 'Hay 1 cobro recurrente que no registraste' : 'Hay ${ghosts.length} cobros recurrentes que no registraste'}${data.untrackedMonthly.isNotEmpty ? ': ≈ $totals al mes.' : ''}',
                style: CrText.body(c.ink),
              ),
            if (data.alerts.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: CrBadge(data.alerts.length == 1 ? '1 alerta' : '${data.alerts.length} alertas', tone: Tone.warning, icon: 'up'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: CrLink('Revisar', onTap: () => context.go('/subscriptions')),
            ),
          ],
        ),
      );
    },
  );
}
