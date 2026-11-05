import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/screens/analytics.dart';
import 'package:alvea_app/ui/category_icon.dart';
import 'package:alvea_app/ui/week_strip.dart';
import 'package:flutter_test/flutter_test.dart';

Summary _summary(String month, double income, double expense, Map<String?, double> byCat) => Summary.fromJson({
  'month': month,
  'currency': 'COP',
  'currencies': ['COP'],
  'income': '$income',
  'expense': '$expense',
  'expense_by_category': [
    for (final e in byCat.entries) {'category_id': e.key, 'total': '${e.value}'},
  ],
  'trend': [
    for (var i = 1; i <= 6; i++) {'month': '2026-0$i-01', 'income': '${i * 10}', 'expense': '$i'},
  ],
});

void main() {
  test('el icono de la categoría sale del nombre, con o sin tildes', () {
    expect(categoryIcon('Comida'), 'food');
    expect(categoryIcon('Educación'), 'school');
    expect(categoryIcon('Arriendo apartamento'), 'home');
    expect(categoryIcon('Netflix'), 'film');
    expect(categoryIcon('Gasolina'), 'car');
    expect(categoryIcon('Sueldo', kind: 'income'), 'salary');
    expect(categoryIcon('Cosas raras'), 'tag');
    expect(categoryIcon('Cosas raras', kind: 'income'), 'receive');
  });

  test('el periodo suma los meses y ordena el gasto por categoría', () {
    final r = PeriodReport.combine([
      _summary('2026-06-01', 100, 40, {'a': 30, 'b': 10}),
      _summary('2026-05-01', 50, 30, {'b': 25, null: 5}),
    ], 3);
    expect(r.income, 150);
    expect(r.expense, 70);
    expect(r.net, 80);
    expect(r.byCategory.first, (categoryId: 'b', total: 35.0));
    expect(r.trend.length, 3); // al menos 3 meses en el gráfico
    expect(r.trend.last.month, '2026-06-01');
  });

  test('la semana empieza el lunes', () {
    expect(weekStart(DateTime(2026, 11, 5)), DateTime(2026, 11, 2)); // jueves → lunes
    expect(weekStart(DateTime(2026, 11, 8)), DateTime(2026, 11, 2)); // domingo → lunes anterior
    expect(weekStart(DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
  });
}
