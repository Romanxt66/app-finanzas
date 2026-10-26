import 'dart:async';

import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/download.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

const pageSize = 20;
const typeLabels = {'income': 'Ingreso', 'expense': 'Gasto', 'transfer': 'Transferencia'};

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _searchText = '';
  String _type = '';
  String _account = '';
  String _from = '';
  String _to = '';
  int _page = 0;
  bool _formOpen = false;
  Transaction? _editing;
  bool _exporting = false;
  Object? _exportError;
  Object? _removeError;

  Map<String, Object?> get _filters => {'search': _searchText, 'type': _type, 'account_id': _account, 'date_from': _from, 'date_to': _to};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setFilter(VoidCallback f) => setState(() {
    f();
    _page = 0;
  });

  Future<void> _export() async {
    final app = context.app;
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      final bytes = await app.api.bytes('/transactions/export', query: _filters);
      saveFile(bytes, 'movimientos.csv');
    } catch (e) {
      if (mounted) setState(() => _exportError = e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ref = context.ref;
    final c = context.c;
    return Query<TransactionPage>(
      deps: '${_filters.values.join('|')}$_page',
      load: () => app.data.transactions({..._filters, 'limit': pageSize, 'offset': _page * pageSize}),
      builder: (context, q) {
        final data = q.data;
        final pages = data == null ? 1 : (data.total / pageSize).ceil().clamp(1, 1 << 30);
        return PageScaffold(
          children: [
            PageHead(
              'Movimientos',
              headline: 'Cada movimiento, *en su sitio*.',
              actions: [
                Wrap(
                  spacing: space3,
                  runSpacing: space3,
                  children: [
                    CrButton(
                      variant: CrButtonVariant.ghost,
                      icon: 'download',
                      label: 'Exportar CSV',
                      onPressed: _exporting ? null : _export,
                    ),
                    if (!_formOpen)
                      CrButton(
                        variant: CrButtonVariant.primary,
                        icon: 'plus',
                        label: 'Nueva',
                        onPressed: () => setState(() {
                          _formOpen = true;
                          _editing = null;
                        }),
                      ),
                  ],
                ),
              ],
            ),
            ErrorText(_exportError),
            if (_formOpen)
              TransactionForm(key: ValueKey(_editing?.id ?? 'new'), editing: _editing, onDone: () => setState(() => _formOpen = false)),
            CrCard(
              title: 'Filtros',
              child: FormGrid(
                children: [
                  CrTextField(
                    label: 'Buscar',
                    controller: _search,
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () => _setFilter(() => _searchText = v.trim()));
                    },
                  ),
                  CrSelect<String>(
                    label: 'Tipo',
                    value: _type,
                    options: [('', 'Todos'), for (final e in typeLabels.entries) (e.key, e.value)],
                    onChanged: (v) => _setFilter(() => _type = v),
                  ),
                  CrSelect<String>(
                    label: 'Cuenta',
                    value: _account,
                    options: [('', 'Todas'), for (final a in ref.allAccounts) (a.id, a.name)],
                    onChanged: (v) => _setFilter(() => _account = v),
                  ),
                  CrDateField(label: 'Desde', value: _from, optional: true, onChanged: (v) => _setFilter(() => _from = v ?? '')),
                  CrDateField(label: 'Hasta', value: _to, optional: true, onChanged: (v) => _setFilter(() => _to = v ?? '')),
                ],
              ),
            ),
            if (q.loading)
              const Skeleton(lines: 4)
            else if (q.error != null && data == null)
              CrCard(child: CrEmpty(q.error.toString()))
            else if (data == null || data.items.isEmpty)
              const CrCard(child: CrEmpty('No hay transacciones.'))
            else
              GlassList(label: 'Movimientos', children: [for (var i = 0; i < data.items.length; i++) _row(context, data.items[i], i, ref)]),
            ErrorText(_removeError),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: space3,
              runSpacing: space3,
              children: [
                Text('${data?.total ?? 0} resultados', style: CrText.label(c.inkMuted)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CrButton(
                      variant: CrButtonVariant.ghost,
                      small: true,
                      label: 'Anterior',
                      onPressed: _page == 0 ? null : () => setState(() => _page--),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: space3),
                      child: Text('${_page + 1} / $pages', style: CrText.label(c.ink)),
                    ),
                    CrButton(
                      variant: CrButtonVariant.ghost,
                      small: true,
                      label: 'Siguiente',
                      onPressed: _page + 1 >= pages ? null : () => setState(() => _page++),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, Transaction t, int i, RefData ref) {
    final account = ref.account(t.accountId);
    final category = t.categoryId != null ? ref.categoryName(t.categoryId) : null;
    final target = t.transferAccountId != null ? ref.account(t.transferAccountId!)?.name : null;
    return TransactionRow(
      first: i == 0,
      index: i,
      kind: txKind(t.type),
      title: t.description.isNotEmpty ? t.description : (category ?? typeLabels[t.type]!),
      detail: [
        formatDate(t.occurredOn),
        target != null ? '${account?.name} → $target' : account?.name,
        category,
        if (t.type == 'expense') lifeHoursNote(t.amount, ref.hourlyRate),
      ].whereType<String>().join(' · '),
      amount: t.amount,
      currency: account?.currency,
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CrButton(
            variant: CrButtonVariant.ghost,
            small: true,
            icon: 'edit',
            tooltip: 'Editar',
            onPressed: () => setState(() {
              _formOpen = true;
              _editing = t;
            }),
          ),
          CrButton(
            variant: CrButtonVariant.danger,
            small: true,
            icon: 'trash',
            tooltip: 'Eliminar',
            onPressed: () async {
              final app = context.app;
              if (!await showConfirm(
                context,
                title: '¿Eliminar este movimiento?',
                body: 'Se ajustará el saldo de la cuenta. Esta acción no se puede deshacer.',
              )) {
                return;
              }
              try {
                setState(() => _removeError = null);
                await app.data.delete('/transactions/${t.id}', 'Movimiento eliminado');
              } catch (e) {
                if (mounted) setState(() => _removeError = e);
              }
            },
          ),
        ],
      ),
    );
  }
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key, required this.editing, required this.onDone});
  final Transaction? editing;
  final VoidCallback onDone;

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  late String _type = widget.editing?.type ?? 'expense';
  late String _account = widget.editing?.accountId ?? '';
  late String _transfer = widget.editing?.transferAccountId ?? '';
  late String _category = widget.editing?.categoryId ?? '';
  late final _amount = TextEditingController(
    text: widget.editing == null ? '' : '${double.parse(widget.editing!.amountRaw)}'.replaceAll(RegExp(r'\.0$'), ''),
  );
  late final _desc = TextEditingController(text: widget.editing?.description ?? '');
  late String _date = widget.editing?.occurredOn ?? todayISO();
  bool _submitted = false;
  bool _busy = false;
  Object? _error;

  String? get _accountError => _submitted && _account.isEmpty ? 'Elige una cuenta' : null;
  String? get _transferError => _submitted && _type == 'transfer' && _transfer.isEmpty ? 'Elige la cuenta destino' : null;
  String? get _amountError => _submitted && parseAmount(_amount.text) == null ? amountError : null;
  String? get _dateError => _submitted && _date.isEmpty ? 'Requerida' : null;
  String? get _descError => _submitted && _desc.text.length > 255 ? 'Máximo 255 caracteres' : null;

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if ([_accountError, _transferError, _amountError, _dateError, _descError].any((e) => e != null) || _busy) {
      return;
    }
    final data = context.app.data;
    setState(() => _busy = true);
    final body = {
      'type': _type,
      'account_id': _account,
      'transfer_account_id': _type == 'transfer' ? _transfer : null,
      'category_id': _type == 'transfer' || _category.isEmpty ? null : _category,
      'amount': parseAmount(_amount.text),
      'description': _desc.text,
      'occurred_on': _date,
    };
    try {
      if (widget.editing != null) {
        await data.put('/transactions/${widget.editing!.id}', body, 'Movimiento guardado');
      } else {
        await data.post('/transactions', body, 'Movimiento guardado');
      }
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final accounts = [for (final a in ref.allAccounts) (a.id, '${a.name} (${a.currency})')];
    return CrCard(
      title: widget.editing != null ? 'Editar transacción' : 'Nueva transacción',
      child: Stack12(
        children: [
          FormGrid(
            children: [
              CrSelect<String>(
                label: 'Tipo',
                value: _type,
                options: [for (final e in typeLabels.entries) (e.key, e.value)],
                onChanged: (v) => setState(() {
                  _type = v;
                  _category = '';
                }),
              ),
              CrSelect<String>(
                label: _type == 'transfer' ? 'Cuenta origen' : 'Cuenta',
                value: _account,
                error: _accountError,
                options: [('', 'Selecciona…'), ...accounts],
                onChanged: (v) => setState(() => _account = v),
              ),
              if (_type == 'transfer')
                CrSelect<String>(
                  label: 'Cuenta destino',
                  value: _transfer,
                  error: _transferError,
                  options: [('', 'Selecciona…'), ...accounts],
                  onChanged: (v) => setState(() => _transfer = v),
                )
              else
                CategorySelect(kind: _type, value: _category, onChanged: (v) => setState(() => _category = v)),
              CrTextField(
                label: 'Monto',
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                error: _amountError,
                onChanged: (_) => setState(() {}),
              ),
              CrDateField(label: 'Fecha', value: _date, error: _dateError, onChanged: (v) => setState(() => _date = v ?? '')),
              CrTextField(label: 'Descripción', controller: _desc, error: _descError, onChanged: (_) => setState(() {})),
            ],
          ),
          Wrap(
            spacing: space3,
            runSpacing: space3,
            children: [
              CrButton(variant: CrButtonVariant.primary, label: 'Guardar', onPressed: _busy ? null : _save),
              CrButton(variant: CrButtonVariant.ghost, label: 'Cancelar', onPressed: widget.onDone),
            ],
          ),
          ErrorText(_error),
        ],
      ),
    );
  }
}
