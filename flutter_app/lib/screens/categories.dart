import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
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
          GridCols(
            children: [
              for (final k in kinds.entries)
                CrCard(
                  title: k.value,
                  child: Builder(
                    builder: (context) {
                      final items = ref.categories.where((x) => x.kind == k.key).toList();
                      if (items.isEmpty) {
                        return const CrEmpty('Sin categorías.');
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            RowSplit(
                              first: true,
                              index: i,
                              children: [
                                Text(items[i].name, style: CrText.body(c.ink)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CrButton(
                                      variant: CrButtonVariant.ghost,
                                      small: true,
                                      icon: 'edit',
                                      tooltip: 'Renombrar ${items[i].name}',
                                      onPressed: () => showFieldDialog(
                                        context,
                                        title: 'Renombrar categoría',
                                        label: 'Nombre',
                                        initial: items[i].name,
                                        onSubmit: (name) =>
                                            context.app.data.patch('/categories/${items[i].id}', {'name': name}, 'Categoría renombrada'),
                                      ),
                                    ),
                                    CrButton(
                                      variant: CrButtonVariant.danger,
                                      small: true,
                                      label: 'Eliminar',
                                      onPressed: () async {
                                        final data = context.app.data;
                                        if (!await showConfirm(
                                          context,
                                          title: '¿Eliminar la categoría "${items[i].name}"?',
                                          body: 'Solo se puede eliminar si no tiene movimientos asociados.',
                                        )) {
                                          return;
                                        }
                                        try {
                                          setState(() => _removeError = null);
                                          await data.delete('/categories/${items[i].id}', 'Categoría eliminada');
                                        } catch (e) {
                                          if (mounted) {
                                            setState(() => _removeError = e);
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ErrorText(_removeError),
      ],
    );
  }
}
