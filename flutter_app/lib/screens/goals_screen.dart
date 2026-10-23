import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int _version = 0;

  Future<List<Goal>> _load() async {
    final raw = await context.app.api.get('/goals') as List;
    return [for (final g in raw) Goal.fromJson(g)];
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return Loader<List<Goal>>(
      key: ValueKey(_version),
      load: _load,
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ScreenTitle(
              'Metas de ahorro',
              action: FilledButton.icon(
                onPressed: () async {
                  if (await showSheet(context, (_) => const _GoalForm())) {
                    setState(() => _version++);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Nueva'),
              ),
            ),
            if (items.isEmpty)
              const EmptyState(
                'Crea una meta para empezar a ahorrar con un objetivo.',
                icon: Icons.flag_outlined,
              )
            else
              for (final g in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                g.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (g.achieved)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: c.mintSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Lograda',
                                  style: TextStyle(
                                    color: c.mint,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Eliminar meta ${g.name}',
                              icon: Icon(
                                Icons.delete_outline,
                                color: c.inkMuted,
                              ),
                              onPressed: () async {
                                if (!await confirm(
                                  context,
                                  'Eliminar meta',
                                  'También se borrarán sus aportes.',
                                )) {
                                  return;
                                }
                                try {
                                  await app.api.delete('/goals/${g.id}');
                                  await reload();
                                } catch (e) {
                                  if (context.mounted) showError(context, e);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: g.target > 0
                                ? (g.saved / g.target).clamp(0, 1)
                                : 0,
                            minHeight: 10,
                            backgroundColor: c.hairline,
                            color: c.amber,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${fmtMoney(g.saved, currency: g.currency)} de ${fmtMoney(g.target, currency: g.currency)}',
                          style: TextStyle(fontSize: 13, color: c.inkMuted),
                        ),
                        if (g.deadline != null)
                          Text(
                            'Hasta el ${fmtDate(g.deadline!)}',
                            style: TextStyle(fontSize: 12, color: c.inkFaint),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _contribute(g, 1, reload),
                              child: const Text('Aportar'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: g.saved > 0
                                  ? () => _contribute(g, -1, reload)
                                  : null,
                              child: const Text('Retirar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _contribute(
    Goal g,
    int sign,
    Future<void> Function() reload,
  ) async {
    if (await showSheet(
      context,
      (_) => _ContributionForm(goal: g, sign: sign),
    )) {
      await reload();
    }
  }
}

class _GoalForm extends StatefulWidget {
  const _GoalForm();

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _currency = TextEditingController(text: 'COP');
  DateTime? _deadline;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await context.app.api.post(
        '/goals',
        body: {
          'name': _name.text.trim(),
          'target_amount': parseAmount(_target.text),
          'currency': _currency.text.trim().toUpperCase(),
          'deadline': _deadline == null ? null : isoDate(_deadline!),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nueva meta',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _target,
          decoration: const InputDecoration(labelText: 'Monto objetivo'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            final a = parseAmount(v ?? '');
            return a == null || double.parse(a) <= 0
                ? 'Escribe un monto mayor que cero'
                : null;
          },
        ),
        const SizedBox(height: 12),
        CurrencyField(controller: _currency),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: Text(
            _deadline == null ? 'Fecha límite (opcional)' : fmtDate(_deadline!),
          ),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => _deadline = d);
          },
        ),
        const SizedBox(height: 16),
        BusyButton(label: 'Crear meta', onPressed: _save),
      ],
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _currency.dispose();
    super.dispose();
  }
}

class _ContributionForm extends StatefulWidget {
  const _ContributionForm({required this.goal, required this.sign});
  final Goal goal;
  final int sign;

  @override
  State<_ContributionForm> createState() => _ContributionFormState();
}

class _ContributionFormState extends State<_ContributionForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final amount = parseAmount(_amount.text)!;
    try {
      await context.app.api.post(
        '/goals/${widget.goal.id}/contributions',
        body: {
          'amount': widget.sign < 0 ? '-$amount' : amount,
          'occurred_on': isoDate(DateTime.now()),
          'note': _note.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.sign > 0 ? 'Aportar a' : 'Retirar de'} ${widget.goal.name}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _amount,
          decoration: const InputDecoration(labelText: 'Monto'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            final a = parseAmount(v ?? '');
            return a == null || double.parse(a) <= 0
                ? 'Escribe un monto mayor que cero'
                : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          maxLength: 200,
        ),
        const SizedBox(height: 8),
        BusyButton(label: 'Guardar', onPressed: _save),
      ],
    ),
  );

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }
}
