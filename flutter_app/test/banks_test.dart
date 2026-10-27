import 'package:alvea_app/ui/banks.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconoce la entidad por el nombre de la cuenta', () {
    expect(bankFor('Nequi')?.id, 'nequi');
    expect(bankFor('nequi ahorros')?.id, 'nequi');
    expect(bankFor('Cuenta Bancolombia nómina')?.id, 'bancolombia');
    expect(bankFor('Banco de Bogotá')?.id, 'bogota');
    expect(bankFor('BBVA')?.id, 'bbva');
    expect(bankFor('Tarjeta Nu')?.id, 'nu');
    expect(bankFor('Daviplata')?.id, 'daviplata');
  });

  test('no confunde palabras que solo contienen el nombre', () {
    expect(bankFor('Ingresos extra'), isNull); // «ing» dentro de «ingresos»
    expect(bankFor('Número de cuenta'), isNull); // «nu» dentro de «número»
    expect(bankFor('Efectivo'), isNull);
  });

  test('cada entidad tiene id único y contraste suficiente en su insignia', () {
    final ids = bankBrands.map((b) => b.id).toSet();
    expect(ids.length, bankBrands.length);
    for (final b in bankBrands) {
      final l1 = b.background.computeLuminance(), l2 = b.foreground.computeLuminance();
      final ratio = ((l1 > l2 ? l1 : l2) + 0.05) / ((l1 > l2 ? l2 : l1) + 0.05);
      expect(ratio, greaterThan(2.0), reason: b.name);
    }
  });

  testWidgets('la insignia muestra la marca o, si no la reconoce, las iniciales', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: const Scaffold(
          body: Row(
            children: [
              BankLogo(name: 'Nequi principal', fallback: 'NP'),
              BankLogo(name: 'Caja fuerte', fallback: 'CF'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('N'), findsOneWidget);
    expect(find.text('CF'), findsOneWidget);
  });
}
