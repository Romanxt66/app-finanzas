import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/budget_period.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/budgets.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _budget(Map<String, dynamic> over) => {
  'id': 'b1',
  'category_id': null,
  'period': 'day',
  'month': '2026-11-11',
  'start': '2026-11-11',
  'recurring': true,
  'amount': '50000.00',
  'spent': '20000.00',
  ...over,
};

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('periodos: la semana empieza el lunes y se recorren hacia atrás y adelante', () {
    final wed = DateTime(2026, 11, 11);
    expect(periodIso('week', wed), '2026-11-09');
    expect(periodIso('week', DateTime(2026, 11, 15)), '2026-11-09'); // domingo
    expect(periodIso('month', wed), '2026-11-01');
    expect(periodIso('day', shiftPeriod('day', DateTime(2026, 11, 30), 1)), '2026-12-01');
    expect(periodIso('week', shiftPeriod('week', wed, -1)), '2026-11-02');
    expect(periodIso('month', shiftPeriod('month', DateTime(2026, 1, 20), -1)), '2025-12-01');
    expect(periodLabel('week', wed), '9 – 15 nov');
    expect(periodLabel('week', DateTime(2026, 11, 30)), '30 nov – 6 dic');
    expect(periodLabel('month', wed), 'noviembre 2026');
  });

  testWidgets('inicio: Hoy / Semana / Mes, se recuerda y manda el general', (tester) async {
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final asked = <String>[];
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (path == '/budgets') asked.add(req.url.queryParameters['period'] ?? '');
      final body = path == '/budgets' && req.url.queryParameters['period'] == 'day'
          ? [
              _budget({}),
              _budget({'id': 'b2', 'category_id': 'c1', 'amount': '10000.00', 'spent': '9000.00'}),
            ]
          : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(body: SingleChildScrollView(child: BudgetHomeCard())),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Aún no tienes presupuesto para este mes'), findsOneWidget);

    await tester.tap(find.text('Hoy'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('te queda hoy'), findsOneWidget);
    // Manda el general (50.000), no la suma con la categoría
    expect(find.textContaining('20.000 de 50.000'), findsOneWidget);
    expect(prefs.getString('home_budget_period'), 'day');
    expect(asked, containsAllInOrder(['month', 'day']));
  });
}
