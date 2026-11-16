import 'models.dart';

/// Cuánto suponen al mes los movimientos que se repiten (gastos e ingresos fijos).
///
/// Una semana cuenta 52/12 ≈ 4,33 veces al mes y un año 1/12. Solo cuentan las reglas activas y
/// vigentes de cuentas en [currency]; las transferencias no cambian lo que tienes.
({double expense, double income, int count}) recurringTotals(
  List<Recurring> rules,
  String? Function(String accountId) currencyOf,
  String currency,
  String today,
) {
  const perMonth = {'weekly': 52 / 12, 'monthly': 1.0, 'yearly': 1 / 12};
  var expense = 0.0, income = 0.0, count = 0;
  for (final r in rules) {
    if (!r.active || (r.endDate != null && r.endDate!.compareTo(today) < 0)) continue;
    if (r.type != 'expense' && r.type != 'income') continue;
    if (currencyOf(r.accountId) != currency) continue;
    final monthly = r.amount * (perMonth[r.frequency] ?? 1);
    if (r.type == 'expense') {
      expense += monthly;
    } else {
      income += monthly;
    }
    count++;
  }
  return (expense: expense, income: income, count: count);
}
