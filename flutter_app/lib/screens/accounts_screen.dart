import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _accountTypes = {
  'cash': 'Efectivo',
  'bank': 'Banco',
  'card': 'Tarjeta',
  'savings': 'Ahorros',
};

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  int _version = 0;

  Future<List<Account>> _load() async {
    final app = context.app;
    await app.loadReference();
    return app.accounts;
  }

  Future<void> _add() async {
    if (await showSheet(context, (_) => const _AccountForm())) {
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Loader<List<Account>>(
      key: ValueKey(_version),
      load: _load,
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ScreenTitle(
              'Cuentas',
              action: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Nueva'),
              ),
            ),
            if (items.isEmpty)
              const EmptyState(
                'Crea tu primera cuenta para empezar a registrar movimientos.',
                icon: Icons.account_balance_wallet_outlined,
              )
            else
              for (final a in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: a.archived ? c.inkFaint : c.ink,
                                ),
                              ),
                              Text(
                                '${_accountTypes[a.type] ?? a.type}${a.archived ? ' · archivada' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Amount(a.balance, currency: a.currency, size: 16),
                        PopupMenuButton<String>(
                          tooltip: 'Opciones de ${a.name}',
                          onSelected: (v) async {
                            final app = context.app;
                            try {
                              if (v == 'archive') {
                                await app.api.patch(
                                  '/accounts/${a.id}',
                                  body: {'archived': !a.archived},
                                );
                              } else if (await confirm(
                                context,
                                'Eliminar cuenta',
                                'Solo se puede eliminar si no tiene movimientos.',
                              )) {
                                await app.api.delete('/accounts/${a.id}');
                              } else {
                                return;
                              }
                              await reload();
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'archive',
                              child: Text(
                                a.archived ? 'Desarchivar' : 'Archivar',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
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

class _AccountForm extends StatefulWidget {
  const _AccountForm();

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _balance = TextEditingController(text: '0');
  final _currency = TextEditingController(text: 'COP');
  String _type = 'bank';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await context.app.api.post(
        '/accounts',
        body: {
          'name': _name.text.trim(),
          'type': _type,
          'currency': _currency.text.trim().toUpperCase(),
          'initial_balance': parseAmount(_balance.text),
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
          'Nueva cuenta',
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
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [
            for (final e in _accountTypes.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _type = v!),
        ),
        const SizedBox(height: 12),
        CurrencyField(controller: _currency),
        TextFormField(
          controller: _balance,
          decoration: const InputDecoration(labelText: 'Saldo inicial'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) =>
              parseAmount(v ?? '') == null ? 'Escribe un monto válido' : null,
        ),
        const SizedBox(height: 16),
        BusyButton(label: 'Crear cuenta', onPressed: _save),
      ],
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _currency.dispose();
    super.dispose();
  }
}
