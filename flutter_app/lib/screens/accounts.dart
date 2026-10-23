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
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'features.dart';

const accountTypeLabels = {'cash': 'Efectivo', 'bank': 'Banco', 'card': 'Tarjeta', 'savings': 'Ahorro'};

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
    final c = context.c;
    final accounts = ref.allAccounts;
    return PageScaffold(
      children: [
        PageHead('Cuentas'),
        CrCard(
          title: 'Nueva cuenta',
          child: Stack12(
            children: [
              FormGrid(
                children: [
                  CrTextField(label: 'Nombre', controller: _name, error: _nameError, onChanged: (_) => setState(() {})),
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
        else
          GlassList(
            children: [
              for (var i = 0; i < accounts.length; i++)
                RowSplit(
                  first: i == 0,
                  index: i,
                  archived: accounts[i].archived,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CrChip('wallet', tone: Tone.brand),
                        const SizedBox(width: space3),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(accounts[i].name, style: CrText.body(c.ink)),
                            Text(
                              '${accountTypeLabels[accounts[i].type] ?? accounts[i].type} · ${accounts[i].currency}',
                              style: CrText.caption(c.inkMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatMoney(accounts[i].balance, accounts[i].currency), style: CrText.amountSm(c.ink)),
                        const SizedBox(width: space3),
                        CrButton(
                          variant: CrButtonVariant.ghost,
                          small: true,
                          icon: 'edit',
                          tooltip: 'Renombrar ${accounts[i].name}',
                          onPressed: () => _rename(accounts[i]),
                        ),
                        CrButton(
                          variant: CrButtonVariant.ghost,
                          small: true,
                          label: accounts[i].archived ? 'Restaurar' : 'Archivar',
                          onPressed: () => _run(
                            () => context.app.data.patch('/accounts/${accounts[i].id}', {
                              'archived': !accounts[i].archived,
                            }, 'Cuenta actualizada'),
                          ),
                        ),
                        CrButton(
                          variant: CrButtonVariant.danger,
                          small: true,
                          icon: 'trash',
                          tooltip: 'Eliminar ${accounts[i].name}',
                          onPressed: () => _delete(accounts[i]),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ErrorText(_removeError),
      ],
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
