import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  String _month = monthStart();
  final _amount = TextEditingController();
  String _category = '';
  bool _submitted = false;
  bool _busy = false;
  Object? _error;
  Object? _removeError;

  String? get _categoryError => _submitted && _category.isEmpty ? 'Elige una categoría' : null;
  String? get _amountError => _submitted && parseAmount(_amount.text) == null ? amountError : null;

  Future<void> _create() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_categoryError != null || _amountError != null || _busy) return;
    final data = context.app.data;
    setState(() => _busy = true);
    try {
      await data.post('/budgets', {'category_id': _category, 'month': _month, 'amount': parseAmount(_amount.text)}, 'Presupuesto creado');
      if (mounted) {
        setState(() {
          _category = '';
          _amount.clear();
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
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ref = context.ref;
    final currency = ref.displayCurrency;
    return Query<List<Budget>>(
      deps: _month,
      load: () => app.data.budgets(_month),
      builder: (context, q) {
        final budgets = q.data;
        return PageScaffold(
          children: [
            PageHead(
              'Presupuestos',
              headline: 'Gasta con *intención*.',
              actions: [
                SizedBox(
                  width: 200,
                  child: CrMonthField(label: 'Mes', month: parseIso(_month), onChanged: (d) => setState(() => _month = monthStart(d))),
                ),
              ],
            ),
            CrCard(
              title: 'Nuevo presupuesto',
              child: Stack12(
                children: [
                  FormGrid(
                    children: [
                      CategorySelect(
                        kind: 'expense',
                        label: 'Categoría de gasto',
                        emptyLabel: 'Selecciona…',
                        value: _category,
                        error: _categoryError,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CrButton(variant: CrButtonVariant.primary, label: 'Añadir', onPressed: _busy ? null : _create),
                  ),
                  ErrorText(_error),
                ],
              ),
            ),
            if (q.loading)
              const Skeleton(lines: 2)
            else if (budgets == null || budgets.isEmpty)
              const CrCard(child: CrEmpty('No hay presupuestos para este mes.'))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < budgets.length; i++) ...[
                    if (i > 0) const SizedBox(height: space3),
                    BudgetBar(
                      label: ref.categoryName(budgets[i].categoryId),
                      spent: budgets[i].spent,
                      limit: budgets[i].amount,
                      currency: currency,
                      actions: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CrButton(
                            variant: CrButtonVariant.ghost,
                            small: true,
                            icon: 'edit',
                            tooltip: 'Editar ${ref.categoryName(budgets[i].categoryId)}',
                            onPressed: () => showFieldDialog(
                              context,
                              title: 'Editar presupuesto de ${ref.categoryName(budgets[i].categoryId)}',
                              label: 'Monto',
                              initial: '${budgets[i].amount}'.replaceAll(RegExp(r'\.0$'), ''),
                              decimal: true,
                              validate: (v) {
                                final a = parseAmount(v);
                                return a != null && double.parse(a) > 0 ? null : amountError;
                              },
                              onSubmit: (v) =>
                                  app.data.patch('/budgets/${budgets[i].id}', {'amount': parseAmount(v)}, 'Presupuesto actualizado'),
                            ),
                          ),
                          CrButton(
                            variant: CrButtonVariant.danger,
                            small: true,
                            label: 'Eliminar',
                            onPressed: () async {
                              final data = app.data;
                              if (!await showConfirm(
                                context,
                                title: '¿Eliminar el presupuesto de ${ref.categoryName(budgets[i].categoryId)}?',
                              )) {
                                return;
                              }
                              try {
                                setState(() => _removeError = null);
                                await data.delete('/budgets/${budgets[i].id}', 'Presupuesto eliminado');
                              } catch (e) {
                                if (mounted) setState(() => _removeError = e);
                              }
                            },
                          ),
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
