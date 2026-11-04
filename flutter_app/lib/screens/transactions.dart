import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/deal_card.dart';
import '../ui/download.dart';
import '../ui/glass.dart';
import '../ui/icons.dart';
import '../ui/inputs.dart';
import '../ui/motion.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';
import 'insights.dart';

const pageSize = 20;
const typeLabels = {'income': 'Ingreso', 'expense': 'Gasto', 'transfer': 'Transferencia'};

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.link});

  /// Dirección con la que se abrió (p. ej. /transactions?mover=… desde un recordatorio de cobro).
  final Uri? link;

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

  /// Filtros avanzados (tipo, cuenta, fechas) desplegados.
  bool _filtersOpen = false;

  int get _activeFilters => [_type, _account, _from, _to].where((v) => v.isNotEmpty).length;

  /// Búsqueda siempre a mano y el resto de filtros tras un botón (con cuántos hay activos).
  Widget _filterBar(BuildContext context, RefData ref) {
    final active = _activeFilters;
    return Glass(
      lift: true,
      padding: const EdgeInsets.all(space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CrTextField(
                  label: 'Buscar',
                  controller: _search,
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () => _setFilter(() => _searchText = v.trim()));
                  },
                ),
              ),
              const SizedBox(width: space3),
              CrButton(
                variant: _filtersOpen || active > 0 ? CrButtonVariant.primary : CrButtonVariant.glass,
                icon: 'list',
                label: active > 0 ? 'Filtros · $active' : 'Filtros',
                onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
              ),
            ],
          ),
          AnimatedSize(
            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
            curve: crEase,
            alignment: Alignment.topCenter,
            child: !_filtersOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FormGrid(
                          children: [
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
                        if (active > 0) ...[
                          const SizedBox(height: space3),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: CrButton(
                              variant: CrButtonVariant.ghost,
                              small: true,
                              label: 'Quitar filtros',
                              onPressed: () => _setFilter(() {
                                _type = '';
                                _account = '';
                                _from = '';
                                _to = '';
                              }),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Transferencia precargada («Mover dinero» de un recordatorio de cobro).
  TransactionDraft? _draft;
  String? _handledLink;
  bool _exporting = false;
  Object? _exportError;
  Object? _removeError;

  Map<String, Object?> get _filters => {'search': _searchText, 'type': _type, 'account_id': _account, 'date_from': _from, 'date_to': _to};

  @override
  void initState() {
    super.initState();
    _openLink(widget.link);
  }

  @override
  void didUpdateWidget(TransactionsScreen old) {
    super.didUpdateWidget(old);
    if (widget.link != old.link) _openLink(widget.link);
  }

  /// `/transactions?mover=…&desde=…&monto=…&nota=…` abre una transferencia precargada (cuenta destino, origen, monto y nota).
  void _openLink(Uri? uri) {
    final q = uri?.queryParameters ?? const {};
    if (q['mover'] == null || '$uri' == _handledLink) return;
    _handledLink = '$uri';
    _formOpen = true;
    _editing = null;
    _draft = TransactionDraft(
      type: 'transfer',
      account: q['desde'] ?? '',
      transfer: q['mover'] ?? '',
      amount: q['monto'] ?? '',
      description: q['nota'] ?? '',
    );
  }

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
      await app.lock.whileAway(() => saveFile(bytes, 'movimientos.csv'));
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
              TransactionForm(
                key: ValueKey(_editing?.id ?? _handledLink ?? 'new'),
                editing: _editing,
                draft: _editing == null ? _draft : null,
                onDone: () => setState(() {
                  _formOpen = false;
                  _draft = null;
                }),
              ),
            _filterBar(context, ref),
            if (q.loading)
              const Skeleton(lines: 4)
            else if (q.error != null && data == null)
              CrCard(child: CrEmpty(q.error.toString()))
            else if (data == null || data.items.isEmpty)
              const CrCard(child: CrEmpty('No hay transacciones.'))
            else
              _board(context, data.items, ref),
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

  /// Tablero por tipo en pantallas anchas (como un «pipeline»); cuadrícula de tarjetas en móvil o con
  /// un tipo filtrado.
  Widget _board(BuildContext context, List<Transaction> items, RefData ref) {
    final c = context.c;
    if (!context.isWide || _type.isNotEmpty) {
      return CardGrid(
        minWidth: 250,
        children: [
          for (final t in items)
            if (!_hidden.contains(t.id)) _swipeable(context, t, ref),
        ],
      );
    }
    final columns = [
      for (final type in const ['expense', 'income', 'transfer'])
        if (items.any((t) => t.type == type)) type,
    ];
    if (columns.length < 2) {
      return CardGrid(
        minWidth: 250,
        children: [
          for (final t in items)
            if (!_hidden.contains(t.id)) _swipeable(context, t, ref),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: space3),
          Expanded(
            child: Builder(
              builder: (context) {
                final mine = items.where((t) => t.type == columns[i]).toList();
                final currencies = {for (final t in mine) ref.currencyOf(t.accountId)};
                final total = mine.fold<double>(0, (a, t) => a + t.amount);
                return BoardColumn(
                  title: const {'expense': 'Gastos', 'income': 'Ingresos', 'transfer': 'Transferencias'}[columns[i]]!,
                  color: txColor(c, columns[i]),
                  count: mine.length,
                  total: currencies.length == 1 ? formatMoney(total, currencies.first) : null,
                  children: [
                    for (final t in mine)
                      if (!_hidden.contains(t.id)) _swipeable(context, t, ref),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Eliminados al momento (antes de recargar la lista), para que la tarjeta desaparezca ya.
  final _hidden = <String>{};

  /// Elimina sin preguntar y ofrece «Deshacer» unos segundos (lo vuelve a crear igual).
  Future<void> _remove(Transaction t) async {
    final app = context.app;
    setState(() {
      _removeError = null;
      _hidden.add(t.id);
    });
    try {
      await app.api.delete('/transactions/${t.id}');
      app.invalidate();
      final body = {
        'type': t.type,
        'account_id': t.accountId,
        'transfer_account_id': t.transferAccountId,
        'category_id': t.type == 'transfer' ? null : t.categoryId,
        'amount': t.amountRaw,
        'description': t.description,
        'occurred_on': t.occurredOn,
        'mood': t.type == 'expense' ? t.mood : null,
      };
      Future<void> undo() async {
        try {
          await app.data.post('/transactions', body, 'Movimiento recuperado');
        } catch (_) {
          app.onToast?.call('No se pudo recuperar el movimiento');
        }
      }

      if (app.onToastAction != null) {
        app.onToastAction!('Movimiento eliminado', 'Deshacer', undo);
      } else {
        app.onToast?.call('Movimiento eliminado');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hidden.remove(t.id);
          _removeError = e;
        });
      }
    }
  }

  /// Abre el movimiento para editar y sube hasta el formulario.
  void _edit(BuildContext context, Transaction t) {
    setState(() {
      _formOpen = true;
      _editing = t;
    });
    Scrollable.maybeOf(context)?.position.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  /// Deslizar la tarjeta a la izquierda la elimina (con «Deshacer»).
  Widget _swipeable(BuildContext context, Transaction t, RefData ref) {
    final c = context.c;
    return Dismissible(
      key: ValueKey('tx-${t.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        _remove(t);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: space5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [c.negative.withValues(alpha: 0.05), c.negative.withValues(alpha: 0.35)]),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Eliminar', style: CrText.label(c.ink).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: space2),
            CrIcon('trash', size: 18, color: c.ink),
          ],
        ),
      ),
      child: _card(context, t, ref),
    );
  }

  Widget _card(BuildContext context, Transaction t, RefData ref) {
    final c = context.c;
    final account = ref.account(t.accountId);
    final category = t.categoryId != null ? ref.categoryName(t.categoryId) : null;
    final target = t.transferAccountId != null ? ref.account(t.transferAccountId!)?.name : null;
    final title = t.description.isNotEmpty ? t.description : (category ?? typeLabels[t.type]!);
    final color = txColor(c, t.type);
    final sign = switch (t.type) {
      'income' => '+',
      'expense' => '−',
      _ => '',
    };
    return DealCard(
      // Tocar la tarjeta la abre para editar (arriba de la lista)
      onTap: () => _edit(context, t),
      avatar: initials(category ?? title),
      accent: color,
      title: title,
      subtitle: target != null ? '${account?.name} → $target' : account?.name,
      eyebrow: typeLabels[t.type],
      // Signo separado como en el resto de la app («− $ 44.900»), sin partir la línea
      value: sign.isEmpty ? formatMoney(t.amount, account?.currency) : '$sign\u00a0${formatMoney(t.amount, account?.currency)}',
      valueColor: t.type == 'income' ? c.positive : null,
      chips: [
        if (category != null) DealChip(category, dot: true, color: color),
        DealChip(formatDate(t.occurredOn), icon: 'calendar'),
        if (t.mood != null && spendingMoods[t.mood] != null)
          DealChip(spendingMoods[t.mood]!.label.toLowerCase(), color: spendingMoods[t.mood]!.face.color, dot: true),
      ],
      trailing: t.type == 'expense' ? lifeHoursNote(t.amount, ref.hourlyRate)?.replaceFirst(' de trabajo', '') : null,
      actions: [
        CardAction(icon: 'edit', tooltip: 'Editar', onPressed: () => _edit(context, t)),
        CardAction(icon: 'trash', tooltip: 'Eliminar', danger: true, onPressed: () => _remove(t)),
      ],
      semanticLabel: '$title, ${typeLabels[t.type]} de ${formatMoney(t.amount, account?.currency)}, ${formatDate(t.occurredOn)}',
    );
  }
}

/// Valores iniciales de una transacción nueva.
class TransactionDraft {
  const TransactionDraft({this.type = 'expense', this.account = '', this.transfer = '', this.amount = '', this.description = ''});
  final String type, account, transfer, amount, description;
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key, required this.editing, this.draft, required this.onDone});
  final Transaction? editing;
  final TransactionDraft? draft;
  final VoidCallback onDone;

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  late String _type = widget.editing?.type ?? widget.draft?.type ?? 'expense';
  late String _account = widget.editing?.accountId ?? widget.draft?.account ?? '';
  late String _transfer = widget.editing?.transferAccountId ?? widget.draft?.transfer ?? '';
  late String _category = widget.editing?.categoryId ?? '';
  late final _amount = TextEditingController(
    text: widget.editing == null
        ? widget.draft?.amount ?? ''
        : '${double.parse(widget.editing!.amountRaw)}'.replaceAll(RegExp(r'\.0$'), ''),
  );
  late final _desc = TextEditingController(text: widget.editing?.description ?? widget.draft?.description ?? '');
  late String _date = widget.editing?.occurredOn ?? todayISO();
  late String? _mood = widget.editing?.mood;
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
      'mood': _type == 'expense' ? _mood : null,
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
          if (_type == 'expense') MoodPicker(value: _mood, onChanged: (v) => setState(() => _mood = v)),
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
