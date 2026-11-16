import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/screens/goals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Goal _goal(String? deadline) => Goal.fromJson({
  'id': 'g1',
  'name': 'Viaje',
  'currency': 'COP',
  'target_amount': '3000',
  'saved': '1000',
  'remaining': '2000',
  'achieved': false,
  'deadline': deadline,
});

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('con el plazo vencido no dice «para el …» como si aún hubiera tiempo', () {
    final note = goalNote(_goal('2020-03-01'))!;
    expect(note, contains('el plazo venció el'));
    expect(note, isNot(contains('para el')));
  });

  test('con fecha futura sigue diciendo «para el …»', () {
    expect(goalNote(_goal('2099-03-01')), contains('para el'));
  });
}
