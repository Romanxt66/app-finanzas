import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/budget_period.dart';
import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/glass.dart';
import '../ui/icons.dart';
import '../ui/inputs.dart';
import '../ui/motion.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

const generalBudgetLabel = 'Todos los gastos';

/// Nombre que se muestra de un presupuesto: su categoría o «Todos los gastos».
String budgetName(RefData ref, Budget b) => b.categoryId == null ? generalBudgetLabel : ref.categoryName(b.categoryId);

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  /// Formulario de alta desplegado (con datos ya creados empieza plegado).
  bool _formOpen = false;
  String _period = 'month';
  DateTime _date = DateTime.now();
  int _formKey = 0;
  Object? _removeError;

  Future<void> _create(BudgetDraft d) async {
    await context.app.data.post('/budgets', {
      'category_id': d.categoryId.isEmpty ? null : d.categoryId,
      'period': _period,
      'start': isoDate(_date),
      'amount': d.amount,
      'recurring': d.recurring,
    }, 'Presupuesto creado');
    if (mounted) {
      setState(() {
        _formOpen = false;
        _formKey++;
      });
    }
  }

  Future<void> _edit(Budget b) {
    final ref = context.ref;
    final data = context.app.data;
    return showCrDialog<void>(
      context,
      title: 'Editar presupuesto · ${budgetName(ref, b)}',
      builder: (ctx) => BudgetForm(
        period: b.period,
        initial: BudgetDraft(categoryId: b.categoryId ?? '', amount: '${b.amount}'.replaceAll(RegExp(r'\.0$'), ''), recurring: b.recurring),
        submitLabel: 'Guardar',
        onCancel: () => Navigator.pop(ctx),
        onSubmit: (d) async {
          // Solo lo que cambió
          final cat = d.categoryId.isEmpty ? null : d.categoryId;
          await data.patch('/budgets/${b.id}', {
            if (double.parse(d.amount) != b.amount) 'amount': d.amount,
            if (cat != b.categoryId) 'category_id': cat,
            if (d.recurring != b.recurring) 'recurring': d.recurring,
          }, 'Presupuesto actualizado');
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _delete(Budget b) async {
    final data = context.app.data;
    if (!await showConfirm(
      context,
      title: '¿Eliminar el presupuesto de ${budgetName(context.ref, b).toLowerCase()}?',
      body: b.recurring ? 'Se repite: dejará de aplicarse en todos los periodos.' : null,
    )) {
      return;
    }
    try {
      setState(() => _removeError = null);
      await data.delete('/budgets/${b.id}', 'Presupuesto eliminado');
    } catch (e) {
      if (mounted) setState(() => _removeError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ref = context.ref;
    final currency = ref.displayCurrency;
    final c = context.c;
    return Query<List<Budget>>(
      deps: '$_period ${periodIso(_period, _date)}',
      load: () => app.data.budgetsFor(_period, periodIso(_period, _date)),
      builder: (context, q) {
        // El general primero: es el límite de todo lo demás
        final budgets = [...?q.data]..sort((a, b) => (a.categoryId == null ? 0 : 1) - (b.categoryId == null ? 0 : 1));
        return PageScaffold(
          children: [
            PageHead(
              'Presupuestos',
              headline: 'Gasta con *intención*.',
              actions: [
                PeriodPill(
                  label: periodLabel(_period, _date),
                  onPrev: () => setState(() => _date = shiftPeriod(_period, _date, -1)),
                  onNext: () => setState(() => _date = shiftPeriod(_period, _date, 1)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: CrSegmented<String>(
                options: budgetPeriods,
                value: _period,
                onChanged: (v) => setState(() {
                  _period = v;
                  _formKey++;
                }),
              ),
            ),
            CreateSection(
              label: 'Nuevo presupuesto',
              title: 'Nuevo presupuesto',
              open: _formOpen,
              onOpenChanged: (v) => setState(() => _formOpen = v),
              hasData: budgets.isNotEmpty,
              child: BudgetForm(
                key: ValueKey('new-$_period-$_formKey'),
                period: _period,
                initial: const BudgetDraft(categoryId: '', amount: '', recurring: true),
                submitLabel: 'Añadir',
                onSubmit: _create,
              ),
            ),
            if (q.loading && q.data == null)
              const Skeleton(lines: 2)
            else if (budgets.isEmpty)
              CrCard(
                child: CrEmpty(
                  '${switch (_period) {
                    'day' => 'No hay presupuesto para este día.',
                    'week' => 'No hay presupuesto para esta semana.',
                    _ => 'No hay presupuestos para este mes.',
                  }} Crea uno general para controlar todo lo que gastas, o uno por categoría.',
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < budgets.length; i++) ...[
                    if (i > 0) const SizedBox(height: space3),
                    BudgetBar(
                      label: budgetName(ref, budgets[i]),
                      spent: budgets[i].spent,
                      limit: budgets[i].amount,
                      currency: currency,
                      actions: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (budgets[i].recurring) ...[
                            CrIcon('restore', size: 14, color: c.inkFaint),
                            const SizedBox(width: 4),
                            Text('se repite', style: CrText.mono(c.inkFaint, size: 11)),
                            const SizedBox(width: space2),
                          ],
                          CrButton(
                            variant: CrButtonVariant.ghost,
                            small: true,
                            icon: 'edit',
                            tooltip: 'Editar ${budgetName(ref, budgets[i])}',
                            onPressed: () => _edit(budgets[i]),
                          ),
                          CrButton(variant: CrButtonVariant.danger, small: true, label: 'Eliminar', onPressed: () => _delete(budgets[i])),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ErrorText(_removeError),
          ],
        );
      },
    );
  }
}

class BudgetDraft {
  const BudgetDraft({required this.categoryId, required this.amount, required this.recurring});

  /// Vacío: todos los gastos.
  final String categoryId;
  final String amount;
  final bool recurring;
}

/// Formulario de presupuesto: para qué (una categoría o todos los gastos), cuánto y si se repite.
class BudgetForm extends StatefulWidget {
  const BudgetForm({
    super.key,
    required this.period,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.onCancel,
  });
  final String period;
  final BudgetDraft initial;
  final String submitLabel;
  final Future<void> Function(BudgetDraft draft) onSubmit;
  final VoidCallback? onCancel;

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  late String _category = widget.initial.categoryId;
  late final _amount = TextEditingController(text: widget.initial.amount);
  late bool _recurring = widget.initial.recurring;
  bool _submitted = false;
  bool _busy = false;
  Object? _error;

  String? get _amountError => _submitted && parseAmount(_amount.text) == null ? amountError : null;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    final amount = parseAmount(_amount.text);
    if (amount == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(BudgetDraft(categoryId: _category, amount: amount, recurring: _recurring));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack12(
    children: [
      FormGrid(
        children: [
          CategorySelect(
            kind: 'expense',
            label: 'Para',
            emptyLabel: '$generalBudgetLabel (general)',
            value: _category,
            onChanged: (v) => setState(() => _category = v),
          ),
          CrTextField(
            label: 'Monto',
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: _amountError,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      CrCheckbox(value: _recurring, label: 'Repetir ${budgetEvery[widget.period]}', onChanged: (v) => setState(() => _recurring = v)),
      ErrorText(_error),
      Row(
        mainAxisAlignment: widget.onCancel == null ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (widget.onCancel != null) ...[
            CrButton(label: 'Cancelar', variant: CrButtonVariant.ghost, onPressed: widget.onCancel),
            const SizedBox(width: space2),
          ],
          CrButton(variant: CrButtonVariant.primary, label: widget.submitLabel, onPressed: _busy ? null : _submit),
        ],
      ),
    ],
  );
}

/// Píldora para recorrer periodos (‹ etiqueta ›).
class PeriodPill extends StatelessWidget {
  const PeriodPill({super.key, required this.label, required this.onPrev, required this.onNext});
  final String label;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget arrow(String tip, bool next) => Semantics(
      button: true,
      label: tip,
      excludeSemantics: true,
      child: InkResponse(
        radius: 20,
        onTap: next ? onNext : onPrev,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Transform.rotate(
              angle: next ? -1.5708 : 1.5708,
              child: CrIcon('chevron', size: 16, color: c.inkMuted),
            ),
          ),
        ),
      ),
    );
    return Glass(
      radius: radiusPill,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow('Anterior', false),
          Semantics(
            liveRegion: true,
            child: Text(label, style: CrText.label(c.ink).copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          arrow('Siguiente', true),
        ],
      ),
    );
  }
}

/// Presupuesto en el inicio: eliges si ver el de hoy, el de la semana o el del mes (se recuerda).
/// Si hay uno general manda ese; si no, suma los de cada categoría.
class BudgetHomeCard extends StatelessWidget {
  const BudgetHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final currency = context.ref.displayCurrency;
    final period = app.homeBudgetPeriod;
    final now = DateTime.now();
    return Query<List<Budget>>(
      deps: '$period ${todayISO()}',
      load: () => app.data.budgetsFor(period, todayISO()),
      builder: (context, q) {
        final list = q.data ?? const <Budget>[];
        final general = list.where((b) => b.categoryId == null).firstOrNull;
        final shown = general != null ? [general] : list;
        final limit = shown.fold<double>(0, (t, b) => t + b.amount);
        final spent = shown.fold<double>(0, (t, b) => t + b.spent);
        final ratio = limit > 0 ? spent / limit : 0.0;
        final over = ratio > 1;
        final warn = !over && ratio >= 0.8;
        final left = limit - spent;
        final word = budgetNow[period]!;
        return CrCard(
          title: 'Presupuesto',
          action: CrSegmented<String>(
            options: [for (final p in budgetPeriods) (p.$1, p.$1 == 'day' ? 'Hoy' : p.$2)],
            value: period,
            onChanged: app.setHomeBudgetPeriod,
          ),
          child: q.loading && q.data == null
              ? const Skeleton(lines: 1)
              : limit <= 0
              ? Row(
                  children: [
                    Expanded(child: Text('Aún no tienes presupuesto para $word.', style: CrText.body(c.inkMuted))),
                    CrButton(
                      variant: CrButtonVariant.ghost,
                      small: true,
                      label: 'Crear',
                      icon: 'plus',
                      onPressed: () => GoRouter.of(context).go('/budgets'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(left >= 0 ? 'te queda $word' : 'te pasaste', style: CrText.mono(c.inkFaint, size: 11.5)),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: space3,
                      children: [
                        AnimatedMoney(value: left.abs(), currency: currency, style: CrText.display(over ? c.negative : c.ink, size: 34)),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${formatMoney(spent, currency)} de ${formatMoney(limit, currency)}',
                            style: CrText.label(c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: space3),
                    Semantics(
                      label: 'Presupuesto de $word',
                      value: '${(ratio.clamp(0, 1) * 100).round()} %',
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: over ? c.negativeSoft : (warn ? c.amberSoft : c.hairline),
                          borderRadius: BorderRadius.circular(radiusPill),
                        ),
                        child: GrowBar(ratio: ratio, color: over ? c.negative : (warn ? c.amber : c.neon), height: 8, glow: true),
                      ),
                    ),
                    const SizedBox(height: space2),
                    Text(
                      '${(ratio * 100).round()} % · ${periodLabel(period, now)}'
                      '${general != null
                          ? ' · general'
                          : list.length > 1
                          ? ' · ${list.length} categorías'
                          : ''}',
                      style: CrText.mono(c.inkMuted, size: 11.5),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
