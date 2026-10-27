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

const frequencyLabels = {'weekly': 'Cada semana', 'monthly': 'Cada mes', 'yearly': 'Cada año'};
const _typeLabels = {'income': 'Ingreso', 'expense': 'Gasto', 'transfer': 'Transferencia'};

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  String _type = 'expense';
  String _account = '';
  String _transfer = '';
  String _category = '';
  String _frequency = 'monthly';
  String _start = todayISO();
  String _end = '';
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  bool _submitted = false;
  bool _busy = false;
  Object? _error;
  Object? _actionError;

  String? get _accountError => _submitted && _account.isEmpty ? 'Elige una cuenta' : null;
  String? get _transferError => _submitted && _type == 'transfer' && _transfer.isEmpty ? 'Elige la cuenta destino' : null;
  String? get _amountError => _submitted && parseAmount(_amount.text) == null ? amountError : null;
  String? get _startError => _submitted && _start.isEmpty ? 'Requerida' : null;
  String? get _endError =>
      _submitted && _end.isNotEmpty && _end.compareTo(_start) < 0 ? 'La fecha final no puede ser anterior a la inicial' : null;
  String? get _descError => _submitted && _desc.text.length > 255 ? 'Máximo 255 caracteres' : null;

  Future<void> _create() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if ([_accountError, _transferError, _amountError, _startError, _endError, _descError].any((e) => e != null) || _busy) {
      return;
    }
    final data = context.app.data;
    setState(() => _busy = true);
    try {
      await data.post('/recurring', {
        'type': _type,
        'account_id': _account,
        'transfer_account_id': _type == 'transfer' ? _transfer : null,
        'category_id': _type == 'transfer' || _category.isEmpty ? null : _category,
        'amount': parseAmount(_amount.text),
        'description': _desc.text,
        'frequency': _frequency,
        'start_date': _start,
        'end_date': _end.isEmpty ? null : _end,
      }, 'Movimiento recurrente creado');
      if (mounted) {
        setState(() {
          _amount.clear();
          _desc.clear();
          _account = '';
          _transfer = '';
          _category = '';
          _end = '';
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
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ref = context.ref;
    final active = [for (final a in ref.accounts) (a.id, '${a.name} (${a.currency})')];
    return Query<List<Recurring>>(
      load: () => app.data.recurring(),
      builder: (context, q) {
        final rules = q.data;
        return PageScaffold(
          children: [
            PageHead('Recurrentes', headline: 'Lo que se repite, *se registra solo*.'),
            CrCard(
              title: 'Nuevo movimiento recurrente',
              child: Stack12(
                children: [
                  FormGrid(
                    children: [
                      CrSelect<String>(
                        label: 'Tipo',
                        value: _type,
                        options: [for (final e in _typeLabels.entries) (e.key, e.value)],
                        onChanged: (v) => setState(() {
                          _type = v;
                          _category = '';
                        }),
                      ),
                      CrSelect<String>(
                        label: _type == 'transfer' ? 'Cuenta origen' : 'Cuenta',
                        value: _account,
                        error: _accountError,
                        options: [('', 'Selecciona…'), ...active],
                        onChanged: (v) => setState(() => _account = v),
                      ),
                      if (_type == 'transfer')
                        CrSelect<String>(
                          label: 'Cuenta destino',
                          value: _transfer,
                          error: _transferError,
                          options: [('', 'Selecciona…'), ...active],
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
                      CrSelect<String>(
                        label: 'Frecuencia',
                        value: _frequency,
                        options: [for (final e in frequencyLabels.entries) (e.key, e.value)],
                        onChanged: (v) => setState(() => _frequency = v),
                      ),
                      CrDateField(
                        label: 'Primera fecha',
                        value: _start,
                        error: _startError,
                        onChanged: (v) => setState(() => _start = v ?? ''),
                      ),
                      CrDateField(
                        label: 'Hasta (opcional)',
                        value: _end,
                        optional: true,
                        error: _endError,
                        onChanged: (v) => setState(() => _end = v ?? ''),
                      ),
                      CrTextField(label: 'Descripción', controller: _desc, error: _descError, onChanged: (_) => setState(() {})),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CrButton(variant: CrButtonVariant.primary, label: 'Crear recurrente', onPressed: _busy ? null : _create),
                  ),
                  ErrorText(_error),
                ],
              ),
            ),
            if (q.loading)
              const Skeleton(lines: 3)
            else if (rules == null || rules.isEmpty)
              const CrCard(child: CrEmpty('Aún no tienes movimientos recurrentes. Crea uno para tu sueldo, arriendo o suscripciones.'))
            else
              CardGrid(minWidth: 250, children: [for (final r in rules) _card(context, r, ref)]),
            ErrorText(_actionError),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, Recurring r, RefData ref) {
    final c = context.c;
    final account = ref.account(r.accountId);
    final category = r.categoryId != null ? ref.categoryName(r.categoryId) : null;
    final title = r.description.isNotEmpty ? r.description : (category ?? _typeLabels[r.type]!);
    final color = txColor(c, r.type);
    return DealCard(
      avatar: initials(category ?? title),
      accent: color,
      title: title,
      subtitle: account?.name,
      eyebrow: '${_typeLabels[r.type]} · ${frequencyLabels[r.frequency]?.toLowerCase()}',
      value: '${r.type == 'income' ? '+' : (r.type == 'expense' ? '−' : '')}${formatMoney(r.amount, account?.currency)}',
      valueColor: r.type == 'income' ? c.positive : null,
      dimmed: !r.active,
      chips: [
        if (r.active) DealChip('próximo ${formatDate(r.nextDate)}', icon: 'calendar') else const DealChip('pausado', icon: 'archive'),
        if (category != null) DealChip(category, dot: true, color: color),
      ],
      actions: [
        CardAction(
          icon: r.active ? 'archive' : 'restore',
          tooltip: '${r.active ? 'Pausar' : 'Reanudar'} $title',
          onPressed: () async {
            try {
              setState(() => _actionError = null);
              await context.app.data.patch('/recurring/${r.id}', {
                'active': !r.active,
              }, r.active ? 'Recurrente pausado' : 'Recurrente actualizado');
            } catch (e) {
              if (mounted) setState(() => _actionError = e);
            }
          },
        ),
        CardAction(
          icon: 'trash',
          tooltip: 'Eliminar',
          danger: true,
          onPressed: () async {
            final data = context.app.data;
            if (!await showConfirm(
              context,
              title: '¿Eliminar este movimiento recurrente?',
              body: 'Los movimientos ya registrados se conservan; solo dejará de generar nuevos.',
            )) {
              return;
            }
            try {
              setState(() => _actionError = null);
              await data.delete('/recurring/${r.id}', 'Recurrente eliminado');
            } catch (e) {
              if (mounted) setState(() => _actionError = e);
            }
          },
        ),
      ],
      semanticLabel: '$title, ${frequencyLabels[r.frequency]}, ${r.active ? 'próximo ${formatDate(r.nextDate)}' : 'pausado'}',
    );
  }
}
