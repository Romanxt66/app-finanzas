import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/core/recurring_totals.dart';
import 'package:flutter_test/flutter_test.dart';

Recurring _rule({
  String type = 'expense',
  String amount = '100',
  String frequency = 'monthly',
  bool active = true,
  String? end,
  String account = 'a',
}) => Recurring.fromJson({
  'id': 'r',
  'type': type,
  'account_id': account,
  'category_id': null,
  'amount': amount,
  'description': '',
  'frequency': frequency,
  'next_date': '2026-12-01',
  'transfer_account_id': null,
  'end_date': end,
  'active': active,
});

void main() {
  test('suma al mes solo lo activo, vigente, de la moneda y que no sea transferencia', () {
    final t = recurringTotals(
      [
        _rule(),
        _rule(type: 'income', amount: '3000'),
        _rule(frequency: 'yearly', amount: '1200'),
        _rule(frequency: 'weekly', amount: '12'),
        _rule(active: false),
        _rule(end: '2026-01-01'),
        _rule(account: 'usd'),
        _rule(type: 'transfer'),
      ],
      (id) => id == 'usd' ? 'USD' : 'COP',
      'COP',
      '2026-11-16',
    );
    expect(t.income, 3000);
    expect(t.expense, closeTo(100 + 100 + 52, 1e-9));
    expect(t.count, 4);
  });
}
