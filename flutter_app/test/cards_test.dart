import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/screens/accounts.dart';
import 'package:alvea_app/screens/flow_chart.dart';
import 'package:alvea_app/ui/deal_card.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.dark),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Transaction _tx(String type, double amount, int daysAgo, {String account = 'a', String? to}) => Transaction.fromJson({
  'id': '$type$amount$daysAgo',
  'type': type,
  'account_id': account,
  'transfer_account_id': to,
  'category_id': null,
  'amount': '$amount',
  'description': '',
  'occurred_on': DateTime.now().subtract(Duration(days: daysAgo)).toIso8601String().substring(0, 10),
});

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('iniciales del avatar', () {
    expect(initials('Cuenta principal'), 'CP');
    expect(initials('banco'), 'BA');
    expect(initials('  '), '·');
  });

  test('el saldo de la mini gráfica se reconstruye hacia atrás desde el saldo actual', () {
    final account = Account.fromJson({'id': 'a', 'name': 'Banco', 'type': 'bank', 'currency': 'EUR', 'archived': false, 'balance': '1000'});
    final series = balanceHistory(account, [
      _tx('income', 500, 40), // hace 40 días entró la nómina
      _tx('expense', 100, 3),
      _tx('transfer', 50, 10, account: 'b', to: 'a'), // llegó dinero de otra cuenta
    ]);
    expect(series.length, 9);
    expect(series.last, 1000);
    expect(series.first, 1000 + 100 - 50 - 500);
  });

  test('la curva suave no baja de cero ni se pasa de los datos', () {
    // Cinco meses en cero y un salto: una curva normal «rebota» por debajo del cero
    final pts = [for (var i = 0; i < 6; i++) Offset(i * 100.0, i < 5 ? 200.0 : 0.0)];
    final bounds = monotonePath(pts).getBounds();
    expect(bounds.bottom, lessThanOrEqualTo(200.01));
    expect(bounds.top, greaterThanOrEqualTo(-0.01));
  });

  testWidgets('la tarjeta muestra título, cifra y chips', (tester) async {
    await tester.pumpWidget(
      _app(
        DealCard(
          avatar: 'CP',
          title: 'Cuenta principal',
          subtitle: 'Banco · EUR',
          eyebrow: 'saldo',
          value: '€ 2.020,12',
          spark: const [1, 2, 3, 2, 4],
          progress: 0.6,
          chips: const [DealChip('Banco', dot: true), DealChip('12 mov.')],
          actions: [CardAction(icon: 'edit', tooltip: 'Renombrar', onPressed: () {})],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cuenta principal'), findsOneWidget);
    expect(find.text('€ 2.020,12'), findsOneWidget);
    expect(find.text('12 mov.'), findsOneWidget);
    expect(find.byTooltip('Renombrar'), findsOneWidget);
  });

  testWidgets('el gráfico de flujo se dibuja y muestra el último mes', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 600,
          child: FlowChart(
            trend: const [
              (month: '2026-08-01', income: 1500.0, expense: 900.0),
              (month: '2026-09-01', income: 1700.0, expense: 950.0),
              (month: '2026-10-01', income: 2000.0, expense: 631.48),
            ],
            currency: 'EUR',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('631,48'), findsOneWidget);
  });
}
