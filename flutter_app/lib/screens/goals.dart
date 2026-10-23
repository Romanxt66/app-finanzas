import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

String? goalNote(Goal g) {
  if (g.achieved) return '¡Meta cumplida!';
  final parts = <String>['Faltan ${formatMoney(g.remaining, g.currency)}'];
  if (g.deadline != null) parts.add('para el ${formatDate(g.deadline!)}');
  final perMonth = monthlyNeeded(deadline: g.deadline == null ? null : parseIso(g.deadline!), remaining: g.remaining, achieved: g.achieved);
  if (perMonth != null) {
    parts.add('· ${formatMoney(perMonth, g.currency)} al mes');
  }
  return parts.join(' ');
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String _currency = '';
  String _deadline = '';
  bool _submitted = false;
  bool _busy = false;
  Object? _error;
  Object? _removeError;

  String? get _nameError => _submitted && (_name.text.trim().isEmpty ? true : _name.text.trim().length > 80)
      ? (_name.text.trim().isEmpty ? 'Requerido' : 'Máximo 80 caracteres')
      : null;
  String? get _targetError => _submitted && parseAmount(_target.text) == null ? amountError : null;
  String? get _currencyError => _submitted && _currency.isEmpty ? 'Selecciona una moneda' : null;

  Future<void> _create() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null || _targetError != null || _currencyError != null || _busy) {
      return;
    }
    final data = context.app.data;
    setState(() => _busy = true);
    try {
      await data.post('/goals', {
        'name': _name.text.trim(),
        'target_amount': parseAmount(_target.text),
        'currency': _currency,
        'deadline': _deadline.isEmpty ? null : _deadline,
      }, 'Meta creada');
      if (mounted) {
        setState(() {
          _name.clear();
          _target.clear();
          _currency = '';
          _deadline = '';
          _submitted = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Query<List<Goal>>(
      load: () => app.data.goals(),
      builder: (context, q) {
        final goals = q.data;
        return PageScaffold(
          children: [
            PageHead('Metas'),
            CrCard(
              title: 'Nueva meta',
              child: Stack12(
                children: [
                  FormGrid(
                    children: [
                      CrTextField(label: 'Nombre', controller: _name, error: _nameError, onChanged: (_) => setState(() {})),
                      CrTextField(
                        label: 'Monto objetivo',
                        controller: _target,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        error: _targetError,
                        onChanged: (_) => setState(() {}),
                      ),
                      CurrencySelect(value: _currency, error: _currencyError, onChanged: (v) => setState(() => _currency = v)),
                      CrDateField(
                        label: 'Fecha límite (opcional)',
                        value: _deadline,
                        optional: true,
                        onChanged: (v) => setState(() => _deadline = v ?? ''),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CrButton(variant: CrButtonVariant.primary, label: 'Crear meta', onPressed: _busy ? null : _create),
                  ),
                  ErrorText(_error),
                ],
              ),
            ),
            if (q.loading)
              const Skeleton(lines: 2, height: 120)
            else if (goals == null || goals.isEmpty)
              const CrCard(child: CrEmpty('Aún no tienes metas. Crea una para empezar a ahorrar con un objetivo.'))
            else
              LayoutBuilder(
                builder: (context, box) {
                  final cols = ((box.maxWidth + space3) / (280 + space3)).floor().clamp(1, 6);
                  final width = (box.maxWidth - space3 * (cols - 1)) / cols;
                  return Wrap(
                    spacing: space3,
                    runSpacing: space3,
                    children: [
                      for (final g in goals)
                        SizedBox(
                          width: width,
                          child: ProgressCard(
                            label: g.name,
                            saved: g.saved,
                            target: g.target,
                            currency: g.currency,
                            achieved: g.achieved,
                            note: goalNote(g),
                            actions: [
                              CrButton(
                                variant: CrButtonVariant.primary,
                                small: true,
                                label: 'Aportar',
                                onPressed: () => _contribution(g, false),
                              ),
                              CrButton(
                                variant: CrButtonVariant.ghost,
                                small: true,
                                label: 'Retirar',
                                onPressed: () => _contribution(g, true),
                              ),
                              CrButton(variant: CrButtonVariant.danger, small: true, label: 'Eliminar', onPressed: () => _delete(g)),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ErrorText(_removeError),
          ],
        );
      },
    );
  }

  Future<void> _delete(Goal g) async {
    final data = context.app.data;
    if (!await showConfirm(
      context,
      title: '¿Eliminar la meta «${g.name}»?',
      body: 'Se borrarán también sus aportes. Esta acción no se puede deshacer.',
    )) {
      return;
    }
    try {
      setState(() => _removeError = null);
      await data.delete('/goals/${g.id}', 'Meta eliminada');
    } catch (e) {
      if (mounted) setState(() => _removeError = e);
    }
  }

  Future<void> _contribution(Goal g, bool withdraw) => showCrDialog<void>(
    context,
    title: '${withdraw ? 'Retirar de' : 'Aportar a'} «${g.name}»',
    builder: (_) => _ContributionForm(goal: g, withdraw: withdraw),
  );
}

class _ContributionForm extends StatefulWidget {
  const _ContributionForm({required this.goal, required this.withdraw});
  final Goal goal;
  final bool withdraw;

  @override
  State<_ContributionForm> createState() => _ContributionFormState();
}

class _ContributionFormState extends State<_ContributionForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _date = todayISO();
  bool _submitted = false;
  bool _busy = false;
  Object? _error;

  String? get _amountError => _submitted && parseAmount(_amount.text) == null ? amountError : null;
  String? get _dateError => _submitted && _date.isEmpty ? 'Requerida' : null;

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_amountError != null || _dateError != null || _busy) return;
    final data = context.app.data;
    setState(() => _busy = true);
    try {
      final amount = parseAmount(_amount.text)!;
      await data.post('/goals/${widget.goal.id}/contributions', {
        'amount': widget.withdraw ? '-$amount' : amount,
        'occurred_on': _date,
        'note': _note.text,
      }, widget.withdraw ? 'Retiro registrado' : 'Aporte registrado');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack12(
    children: [
      CrTextField(
        label: 'Monto',
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        error: _amountError,
        onChanged: (_) => setState(() {}),
      ),
      CrDateField(label: 'Fecha', value: _date, error: _dateError, onChanged: (v) => setState(() => _date = v ?? '')),
      CrTextField(label: 'Nota (opcional)', controller: _note),
      ErrorText(_error),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CrButton(variant: CrButtonVariant.ghost, label: 'Cancelar', onPressed: () => Navigator.pop(context)),
          const SizedBox(width: space2),
          CrButton(variant: CrButtonVariant.primary, label: widget.withdraw ? 'Retirar' : 'Aportar', onPressed: _busy ? null : _save),
        ],
      ),
    ],
  );
}
