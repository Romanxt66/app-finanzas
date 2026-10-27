import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/deal_card.dart';
import '../ui/dialogs.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _name = TextEditingController();
  String _kind = 'expense';
  bool _submitted = false;
  bool _busy = false;
  Object? _error;
  Object? _removeError;

  String? get _nameError => _submitted && (_name.text.trim().isEmpty ? true : _name.text.trim().length > 80)
      ? (_name.text.trim().isEmpty ? 'Requerido' : 'Máximo 80 caracteres')
      : null;

  Future<void> _create() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null || _busy) return;
    final data = context.app.data;
    setState(() => _busy = true);
    try {
      await data.post('/categories', {'name': _name.text.trim(), 'kind': _kind}, 'Categoría creada');
      if (mounted) {
        setState(() {
          _name.clear();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final c = context.c;
    const kinds = {'expense': 'Gastos', 'income': 'Ingresos'};
    return PageScaffold(
      children: [
        PageHead('Categorías', headline: 'Ordena tu dinero *a tu manera*.'),
        CrCard(
          title: 'Nueva categoría',
          child: Stack12(
            children: [
              FormGrid(
                children: [
                  CrTextField(label: 'Nombre', controller: _name, error: _nameError, onChanged: (_) => setState(() {})),
                  CrSelect<String>(
                    label: 'Tipo',
                    value: _kind,
                    options: const [('expense', 'Gasto'), ('income', 'Ingreso')],
                    onChanged: (v) => setState(() => _kind = v),
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
        if (!ref.loaded)
          const Skeleton(lines: 3)
        else
          Query<Summary>(
            load: () => context.app.data.summary(monthStart(), null),
            builder: (context, sq) {
              final spent = {for (final r in sq.data?.byCategory ?? const <({String? categoryId, double total})>[]) r.categoryId: r.total};
              final monthTotal = spent.values.fold<double>(0, (a, b) => a + b);
              final currency = sq.data?.currency;
              return GridCols(
                children: [
                  for (final k in kinds.entries)
                    Builder(
                      builder: (context) {
                        final items = ref.categories.where((x) => x.kind == k.key).toList();
                        final color = txColor(c, k.key);
                        return BoardColumn(
                          title: k.value,
                          color: color,
                          count: items.length,
                          total: k.key == 'expense' && monthTotal > 0 ? '${formatMoney(monthTotal, currency)} este mes' : null,
                          children: items.isEmpty
                              ? [const CrCard(child: CrEmpty('Sin categorías.'))]
                              : [for (final cat in items) _card(context, cat, color, spent[cat.id], monthTotal, currency)],
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ErrorText(_removeError),
      ],
    );
  }

  Widget _card(BuildContext context, Category cat, Color color, double? spent, double monthTotal, String? currency) {
    final expense = cat.kind == 'expense';
    return DealCard(
      avatar: initials(cat.name),
      accent: color,
      title: cat.name,
      subtitle: expense ? 'categoría de gasto' : 'categoría de ingreso',
      eyebrow: expense ? 'este mes' : null,
      value: expense ? formatMoney(spent ?? 0, currency) : null,
      progress: expense && monthTotal > 0 ? (spent ?? 0) / monthTotal : null,
      chips: [if (expense && monthTotal > 0) DealChip('${((spent ?? 0) / monthTotal * 100).round()} % del gasto', dot: true, color: color)],
      actions: [
        CardAction(
          icon: 'edit',
          tooltip: 'Renombrar ${cat.name}',
          onPressed: () => showFieldDialog(
            context,
            title: 'Renombrar categoría',
            label: 'Nombre',
            initial: cat.name,
            onSubmit: (name) => context.app.data.patch('/categories/${cat.id}', {'name': name}, 'Categoría renombrada'),
          ),
        ),
        CardAction(
          icon: 'trash',
          tooltip: 'Eliminar ${cat.name}',
          danger: true,
          onPressed: () async {
            final data = context.app.data;
            if (!await showConfirm(
              context,
              title: '¿Eliminar la categoría "${cat.name}"?',
              body: 'Solo se puede eliminar si no tiene movimientos asociados.',
            )) {
              return;
            }
            try {
              setState(() => _removeError = null);
              await data.delete('/categories/${cat.id}', 'Categoría eliminada');
            } catch (e) {
              if (mounted) setState(() => _removeError = e);
            }
          },
        ),
      ],
    );
  }
}
