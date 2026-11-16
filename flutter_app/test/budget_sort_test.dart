import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/screens/budgets.dart';
import 'package:flutter_test/flutter_test.dart';

Budget _b(String id, String? cat, double amount, double spent) =>
    Budget.fromJson({'id': id, 'category_id': cat, 'amount': '$amount', 'spent': '$spent'});

void main() {
  test('el general primero y luego los más gastados (lo excedido no queda al final)', () {
    final sorted = sortBudgets([_b('comida', 'c1', 200, 20), _b('ocio', 'c2', 200, 300), _b('general', null, 1000, 10)]);
    expect(sorted.map((b) => b.id), ['general', 'ocio', 'comida']);
  });
}
