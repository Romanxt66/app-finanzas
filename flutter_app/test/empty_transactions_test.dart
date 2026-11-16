import 'package:alvea_app/screens/transactions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el vacío de movimientos explica la causa', () {
    expect(emptyTransactionsText(search: 'café', from: '', to: '', activeFilters: 0), contains('«café»'));
    expect(emptyTransactionsText(search: '', from: '2026-11-16', to: '2026-11-16', activeFilters: 2), 'No anotaste nada ese día.');
    expect(emptyTransactionsText(search: '', from: '', to: '', activeFilters: 1), contains('filtros'));
    expect(emptyTransactionsText(search: '', from: '', to: '', activeFilters: 0), startsWith('Aún no hay movimientos'));
  });
}
