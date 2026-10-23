import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  DateTime _month = firstOfMonth(DateTime.now());
  int _version = 0;

  void _go(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<List<Budget>> _load() async {
    final app = context.app;
    await app.loadReference();
    final raw = await app.api.get(
      '/budgets',
      query: {'month': isoDate(_month)},
    ) as List;
    return [for (final b in raw) Budget.fromJson(b)];
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return Loader<List<Budget>>(
      key: ValueKey('$_month$_version'),
      load: _load,
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ScreenTitle(
              'Presupuestos',
              action: FilledButton.icon(
                onPressed: () async {
                  if (await showSheet(
                    context,
                    (_) => _BudgetForm(
                      month: _month,
                      taken: {for (final b in items) b.categoryId},
                    ),
                  )) {
                    setState(() => _version++);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuevo'),
              ),
            ),
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
            if (items.isEmpty)
              const EmptyState(
                'No hay presupuestos para este mes.',
                icon: Icons.pie_chart_outline,
              )
            else
              for (final b in items)
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
                                app.categoryName(b.categoryId),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  'Eliminar presupuesto de ${app.categoryName(b.categoryId)}',
                              icon: Icon(
                                Icons.delete_outline,
                                color: c.inkMuted,
                              ),
                              onPressed: () async {
                                if (!await confirm(
                                  context,
                                  'Eliminar presupuesto',
                                  'Se quitará el límite de esta categoría para el mes.',
                                )) {
                                  return;
                                }
                                try {
                                  await app.api.delete('/budgets/${b.id}');
                                  await reload();
                                } catch (e) {
                                  if (context.mounted) showError(context, e);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          label:
                              'Gastado ${(b.amount > 0 ? b.spent / b.amount * 100 : 0).round()} por ciento',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: b.amount > 0
                                  ? (b.spent / b.amount).clamp(0, 1)
                                  : 0,
                              minHeight: 10,
                              backgroundColor: c.hairline,
                              color: b.spent > b.amount
                                  ? c.negative
                                  : (b.spent > b.amount * 0.8
                                        ? c.amber
                                        : c.mint),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${fmtMoney(b.spent)} de ${fmtMoney(b.amount)}',
                              style: TextStyle(fontSize: 13, color: c.inkMuted),
                            ),
                            Text(
                              b.remaining >= 0
                                  ? 'Quedan ${fmtMoney(b.remaining)}'
                                  : 'Excedido ${fmtMoney(-b.remaining)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: b.remaining >= 0 ? c.ink : c.negative,
                              ),
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
}

class _BudgetForm extends StatefulWidget {
  const _BudgetForm({required this.month, required this.taken});
  final DateTime month;
  final Set<String> taken;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _category;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await context.app.api.post(
        '/budgets',
        body: {
          'category_id': _category,
          'month': isoDate(widget.month),
          'amount': parseAmount(_amount.text),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.app.categories
        .where((c) => c.kind == 'expense' && !widget.taken.contains(c.id))
        .toList();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Presupuesto de ${fmtMonth(widget.month)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Categoría de gasto'),
            items: [
              for (final c in cats)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Elige una categoría' : null,
          ),
          if (cats.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No hay categorías de gasto disponibles.',
                style: TextStyle(color: context.c.inkMuted),
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            decoration: const InputDecoration(labelText: 'Límite del mes'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final a = parseAmount(v ?? '');
              return a == null || double.parse(a) <= 0
                  ? 'Escribe un monto mayor que cero'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          BusyButton(label: 'Guardar', onPressed: _save),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }
}
