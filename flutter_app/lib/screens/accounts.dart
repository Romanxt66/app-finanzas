import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reference.dart';
import '../core/state.dart';
import '../ui/banks.dart';
import '../ui/buttons.dart';
import '../ui/deal_card.dart';
import '../ui/dialogs.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

const accountTypeLabels = {'cash': 'Efectivo', 'bank': 'Banco', 'card': 'Tarjeta', 'savings': 'Ahorro'};

const _sparkDays = 60;

/// Color de cada tipo de cuenta (avatar, chip y línea de progreso).
Color accountTypeColor(CrPalette c, String type) => switch (type) {
  'bank' => c.neon,
  'cash' => c.amber,
  'card' => c.chart3,
  'savings' => c.positive,
  _ => c.chart4,
};

const accountTypeIcons = {'bank': 'wallet', 'cash': 'salary', 'card': 'card', 'savings': 'target'};

/// Saldo de la cuenta en los últimos días (9 puntos), reconstruido hacia atrás desde el saldo actual
/// con los movimientos recientes.
List<double> balanceHistory(Account a, List<Transaction> flows) {
  final now = DateTime.now();
  final points = <double>[];
  var balance = a.balance;
  final mine = flows.where((t) => t.accountId == a.id || t.transferAccountId == a.id).toList();
  for (var k = 0; k <= 8; k++) {
    final from = now.subtract(Duration(days: _sparkDays * k ~/ 8));
    points.add(balance);
    final until = now.subtract(Duration(days: _sparkDays * (k + 1) ~/ 8));
    for (final t in mine) {
      final day = DateTime.tryParse(t.occurredOn);
      if (day == null || !day.isAfter(until) || day.isAfter(from)) continue;
      final delta = switch (t.type) {
        'income' => t.amount,
        'expense' => -t.amount,
        _ => t.accountId == a.id ? -t.amount : t.amount,
      };
      balance -= delta;
    }
  }
  return points.reversed.toList();
}

final _signedAmount = RegExp(r'^-?\d+(\.\d{1,2})?$');

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _name = TextEditingController();
  final _balance = TextEditingController(text: '0');
  String _type = 'bank';
  String _currency = '';
  bool _submitted = false;
  bool _busy = false;
  Object? _error;
  Object? _removeError;
  bool _formOpen = false;

  /// Banco elegido en el formulario ('' = otro).
  String _bank = '';

  /// Tipo de cuenta por el que se filtra ('' = todas).
  String _filter = '';

  String? get _nameError => _submitted && (_name.text.trim().isEmpty ? true : _name.text.trim().length > 80)
      ? (_name.text.trim().isEmpty ? 'Requerido' : 'Máximo 80 caracteres')
      : null;
  String? get _currencyError => _submitted && _currency.isEmpty ? 'Selecciona una moneda' : null;
  String? get _balanceError =>
      _submitted && !_signedAmount.hasMatch(_balance.text.trim().replaceAll(',', '.')) ? 'Número con hasta 2 decimales' : null;

  Future<void> _create() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null || _currencyError != null || _balanceError != null || _busy) {
      return;
    }
    final data = context.app.data;
    setState(() => _busy = true);
    try {
      await data.post('/accounts', {
        'name': _name.text.trim(),
        'type': _type,
        'currency': _currency,
        'initial_balance': _balance.text.trim().replaceAll(',', '.'),
      }, 'Cuenta creada');
      if (mounted) {
        setState(() {
          _formOpen = false;
          _bank = '';
          _name.clear();
          _balance.text = '0';
          _type = 'bank';
          _currency = '';
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
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final accounts = ref.allAccounts;
    final showForm = _formOpen || (ref.loaded && accounts.isEmpty);
    final shown = [
      for (final a in accounts)
        if (_filter.isEmpty || a.type == _filter) a,
    ];
    return PageScaffold(
      children: [
        PageHead(
          'Cuentas',
          headline: 'Tus cuentas, *de un vistazo*.',
          actions: [
            if (!showForm)
              CrButton(
                variant: CrButtonVariant.primary,
                icon: 'plus',
                label: 'Nueva cuenta',
                onPressed: () => setState(() => _formOpen = true),
              ),
          ],
        ),
        if (showForm)
          CrCard(
            title: 'Nueva cuenta',
            child: Stack12(
              children: [
                FormGrid(
                  children: [
                    CrSelect<String>(
                      label: 'Banco o billetera',
                      value: _bank,
                      options: [('', 'Otra (escribe el nombre)'), for (final b in bankBrands) (b.id, b.name)],
                      onChanged: (v) => setState(() {
                        final previous = bankBrands.where((b) => b.id == _bank).firstOrNull;
                        _bank = v;
                        final brand = bankBrands.where((b) => b.id == v).firstOrNull;
                        // Rellena el nombre si está vacío o aún es el del banco elegido antes
                        if (brand != null && (_name.text.trim().isEmpty || _name.text.trim() == previous?.name)) {
                          _name.text = brand.name;
                          _type = brand.type;
                        }
                      }),
                    ),
                    CrTextField(
                      label: 'Nombre',
                      controller: _name,
                      error: _nameError,
                      trailing: bankFor(_name.text) == null
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(right: space2),
                              child: BankLogo(name: _name.text, fallback: '', size: 24),
                            ),
                      onChanged: (_) => setState(() {}),
                    ),
                    CrSelect<String>(
                      label: 'Tipo',
                      value: _type,
                      options: [for (final e in accountTypeLabels.entries) (e.key, e.value)],
                      onChanged: (v) => setState(() => _type = v),
                    ),
                    CurrencySelect(value: _currency, error: _currencyError, onChanged: (v) => setState(() => _currency = v)),
                    CrTextField(
                      label: 'Saldo inicial',
                      controller: _balance,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      error: _balanceError,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CrButton(variant: CrButtonVariant.primary, label: 'Crear cuenta', onPressed: _busy ? null : _create),
                ),
                ErrorText(_error),
              ],
            ),
          ),
        if (!ref.loaded)
          const Skeleton(lines: 3)
        else if (accounts.isEmpty)
          const CrCard(child: CrEmpty('Aún no tienes cuentas.'))
        else ...[
          _TypeSummary(accounts: accounts, selected: _filter, onSelect: (t) => setState(() => _filter = _filter == t ? '' : t)),
          Align(
            alignment: Alignment.centerLeft,
            child: CrSegmented<String>(
              options: [
                ('', 'Todas'),
                for (final e in accountTypeLabels.entries)
                  if (accounts.any((a) => a.type == e.key)) (e.key, e.value),
              ],
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Query<TransactionPage>(
            load: () => context.app.data.transactions({
              'date_from': isoDate(DateTime.now().subtract(const Duration(days: _sparkDays))),
              'limit': 200,
            }),
            builder: (context, tq) {
              final flows = tq.data?.items ?? const <Transaction>[];
              return CardGrid(minWidth: 240, children: [for (final a in shown) _accountCard(a, flows, accounts)]);
            },
          ),
        ],
        ErrorText(_removeError),
      ],
    );
  }

  Widget _accountCard(Account a, List<Transaction> flows, List<Account> all) {
    final c = context.c;
    final color = accountTypeColor(c, a.type);
    final moves = flows.where((t) => t.accountId == a.id || t.transferAccountId == a.id).length;
    final sameCurrency = all.where((x) => x.currency == a.currency && !x.archived);
    final total = sameCurrency.fold<double>(0, (t, x) => t + (x.balance > 0 ? x.balance : 0));
    return DealCard(
      leading: BankLogo(name: a.name, fallback: initials(a.name), color: color),
      accent: color,
      title: a.name,
      subtitle: '${accountTypeLabels[a.type] ?? a.type} · ${a.currency}',
      eyebrow: 'saldo',
      value: formatMoney(a.balance, a.currency),
      valueColor: a.balance < 0 ? c.negative : null,
      spark: balanceHistory(a, flows),
      progress: total > 0 && a.balance > 0 ? a.balance / total : 0,
      dimmed: a.archived,
      chips: [
        DealChip(accountTypeLabels[a.type] ?? a.type, color: color),
        DealChip('$moves mov. en $_sparkDays días', dot: true, color: moves > 0 ? c.positive : c.inkFaint),
        if (a.archived) const DealChip('archivada', icon: 'archive'),
      ],
      actions: [
        CardAction(icon: 'edit', tooltip: 'Renombrar ${a.name}', onPressed: () => _rename(a)),
        CardAction(
          icon: a.archived ? 'restore' : 'archive',
          tooltip: a.archived ? 'Restaurar ${a.name}' : 'Archivar ${a.name}',
          onPressed: () => _run(() => context.app.data.patch('/accounts/${a.id}', {'archived': !a.archived}, 'Cuenta actualizada')),
        ),
        CardAction(icon: 'trash', tooltip: 'Eliminar ${a.name}', danger: true, onPressed: () => _delete(a)),
      ],
      semanticLabel: '${a.name}, saldo ${formatMoney(a.balance, a.currency)}',
    );
  }

  Future<void> _run(Future<void> Function() fn) async {
    try {
      setState(() => _removeError = null);
      await fn();
    } catch (e) {
      if (mounted) setState(() => _removeError = e);
    }
  }

  Future<void> _rename(Account a) => showFieldDialog(
    context,
    title: 'Renombrar cuenta',
    label: 'Nombre',
    initial: a.name,
    onSubmit: (name) => context.app.data.patch('/accounts/${a.id}', {'name': name}, 'Cuenta actualizada'),
  );

  Future<void> _delete(Account a) async {
    final data = context.app.data;
    if (!await showConfirm(
      context,
      title: '¿Eliminar la cuenta «${a.name}»?',
      body: 'Solo se puede eliminar si no tiene movimientos; si los tiene, archívala.',
    )) {
      return;
    }
    await _run(() => data.delete('/accounts/${a.id}', 'Cuenta eliminada'));
  }
}

/// Resumen por tipo de cuenta (icono de color, total, número de cuentas). Al tocarlo filtra.
class _TypeSummary extends StatelessWidget {
  const _TypeSummary({required this.accounts, required this.selected, required this.onSelect});
  final List<Account> accounts;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = accounts.where((a) => !a.archived).toList();
    final currency = active.isEmpty ? null : active.first.currency;
    final grand = active.where((a) => a.currency == currency).fold<double>(0, (t, a) => t + (a.balance > 0 ? a.balance : 0));
    return CardGrid(
      minWidth: 150,
      children: [
        for (final e in accountTypeLabels.entries)
          if (active.any((a) => a.type == e.key))
            Builder(
              builder: (context) {
                final mine = active.where((a) => a.type == e.key).toList();
                final sum = mine.where((a) => a.currency == currency).fold<double>(0, (t, a) => t + a.balance);
                final others = mine.where((a) => a.currency != currency).length;
                return SummaryTile(
                  icon: accountTypeIcons[e.key] ?? 'wallet',
                  color: accountTypeColor(c, e.key),
                  label: e.value,
                  value: formatMoney(sum, currency),
                  note: '${mine.length} cuenta${mine.length == 1 ? '' : 's'}${others > 0 ? ' · $others en otra moneda' : ''}',
                  progress: grand > 0 && sum > 0 ? sum / grand : 0,
                  selected: selected == e.key,
                  onTap: () => onSelect(e.key),
                );
              },
            ),
      ],
    );
  }
}
