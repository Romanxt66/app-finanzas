import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/screens/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx(String id, String amount, {String type = 'expense'}) => Transaction.fromJson({
  'id': id,
  'type': type,
  'account_id': 'a',
  'transfer_account_id': null,
  'category_id': null,
  'amount': amount,
  'description': id,
  'occurred_on': '2026-11-01',
});

void main() {
  test('mayores gastos: solo gastos, de mayor a menor y como mucho cinco', () {
    final top = topExpenses([
      _tx('a', '50'),
      _tx('b', '900'),
      _tx('ingreso', '5000', type: 'income'),
      _tx('c', '120'),
      _tx('d', '10'),
      _tx('e', '300'),
      _tx('f', '70'),
    ]);
    expect([for (final t in top) t.id], ['b', 'e', 'c', 'f', 'a']);
  });
}
