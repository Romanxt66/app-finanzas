import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _typeLabels = {
  'income': 'Ingreso',
  'expense': 'Gasto',
  'transfer': 'Transferencia',
};

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _type;
  String _search = '';
  int _version = 0;

  Future<List<Transaction>> _load() async {
    final app = context.app;
    final page = await app.api.get(
      '/transactions',
      query: {'type': _type, 'search': _search, 'limit': 100},
    ) as Map<String, dynamic>;
    return [for (final t in page['items']) Transaction.fromJson(t)];
  }

  Future<void> _add() async {
    if (await showSheet(context, (_) => const TransactionForm()) && mounted) {
      await context.app.loadReference();
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return Loader<List<Transaction>>(
      key: ValueKey('$_type$_search$_version'),
      load: _load,
      builder: (context, items, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ScreenTitle(
              'Movimientos',
              action: FilledButton.icon(
                onPressed: app.accounts.isEmpty ? null : _add,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo'),
              ),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (v) => setState(() => _search = v.trim()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _type == null,
                  onSelected: (_) => setState(() => _type = null),
                ),
                for (final e in _typeLabels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _type == e.key,
                    onSelected: (_) => setState(() => _type = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (app.accounts.isEmpty)
              const EmptyState(
                'Crea una cuenta en la pestaña Cuentas para registrar movimientos.',
                icon: Icons.account_balance_wallet_outlined,
              )
            else if (items.isEmpty)
              const EmptyState(
                'Aún no hay movimientos.',
                icon: Icons.receipt_long_outlined,
              )
            else
              for (final t in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => confirm(
                      context,
                      'Eliminar movimiento',
                      'Se actualizará el saldo de la cuenta.',
                    ),
                    onDismissed: (_) async {
                      try {
                        await app.api.delete('/transactions/${t.id}');
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                      await reload();
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: c.negativeSoft,
                        borderRadius: BorderRadius.circular(radiusMd),
                      ),
                      child: Icon(Icons.delete_outline, color: c.negative),
                    ),
                    child: _TransactionRow(t),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.t);
  final Transaction t;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final acc = app.account(t.accountId);
    final signed = t.type == 'expense' ? -t.amount : t.amount;
    final title = t.description.isNotEmpty
        ? t.description
        : (t.type == 'transfer'
              ? 'Transferencia'
              : app.categoryName(t.categoryId));
    final icon = switch (t.type) {
      'income' => Icons.south_west,
      'expense' => Icons.north_east,
      _ => Icons.swap_horiz,
    };
    return Glass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.type == 'expense' ? c.negativeSoft : c.mintSoft,
              borderRadius: BorderRadius.circular(radiusSm),
            ),
            child: Icon(
              icon,
              size: 20,
              color: t.type == 'expense' ? c.negative : c.mint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${fmtDate(t.occurredOn)} · ${acc?.name ?? ''}',
                  style: TextStyle(fontSize: 12, color: c.inkMuted),
                ),
              ],
            ),
          ),
          Amount(
            t.type == 'transfer' ? t.amount : signed,
            currency: acc?.currency,
            signed: t.type != 'transfer',
            neutral: t.type == 'transfer',
          ),
        ],
      ),
    );
  }
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String _type = 'expense';
  String? _account, _transfer, _category;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final active = context.app.accounts.where((a) => !a.archived).toList();
    _account = active.firstOrNull?.id;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = context.app;
    try {
      await app.api.post(
        '/transactions',
        body: {
          'type': _type,
          'account_id': _account,
          'transfer_account_id': _type == 'transfer' ? _transfer : null,
          'category_id': _type == 'transfer' ? null : _category,
          'amount': parseAmount(_amount.text),
          'description': _desc.text.trim(),
          'occurred_on': isoDate(_date),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final accounts = app.accounts.where((a) => !a.archived).toList();
    final cats = app.categories.where((c) => c.kind == _type).toList();
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nuevo movimiento',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              for (final e in _typeLabels.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _category = null;
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            decoration: const InputDecoration(labelText: 'Monto'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final a = parseAmount(v ?? '');
              return a == null || double.parse(a) <= 0
                  ? 'Escribe un monto mayor que cero'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _account,
            decoration: InputDecoration(
              labelText: _type == 'transfer' ? 'Cuenta de origen' : 'Cuenta',
            ),
            items: [
              for (final a in accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} (${a.currency})'),
                ),
            ],
            onChanged: (v) => setState(() => _account = v),
            validator: (v) => v == null ? 'Elige una cuenta' : null,
          ),
          const SizedBox(height: 12),
          if (_type == 'transfer')
            DropdownButtonFormField<String>(
              initialValue: _transfer,
              decoration: const InputDecoration(labelText: 'Cuenta de destino'),
              items: [
                for (final a in accounts.where((a) => a.id != _account))
                  DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} (${a.currency})'),
                  ),
              ],
              onChanged: (v) => setState(() => _transfer = v),
              validator: (v) => v == null ? 'Elige la cuenta de destino' : null,
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                for (final c in cats)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
            ),
            maxLength: 200,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(fmtDate(_date)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
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
    _desc.dispose();
    super.dispose();
  }
}
