import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/quick_add.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('es'));

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'a',
      'refresh_token': 'r',
      'user_cache': jsonEncode({'email': 'ana@example.com', 'full_name': 'Ana', 'two_factor_enabled': false}),
    });
    prefs = await SharedPreferences.getInstance();
  });

  http.Client server(List<Map<String, dynamic>> posted, {bool offline = false}) => MockClient((req) async {
    final path = req.url.path.replaceFirst('/api/v1', '');
    if (req.method == 'POST' && path == '/transactions') {
      if (offline) throw Exception('sin red');
      posted.add(jsonDecode(req.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'id': 't1'}), 201);
    }
    final body = switch (path) {
      '/auth/me' => {'email': 'ana@example.com', 'full_name': 'Ana', 'two_factor_enabled': false},
      '/categories' => [
        {'id': 'c1', 'name': 'Comida', 'kind': 'expense'},
        {'id': 'c2', 'name': 'Transporte', 'kind': 'expense'},
        {'id': 'c3', 'name': 'Sueldo', 'kind': 'income'},
      ],
      '/accounts' => [
        {'id': 'n', 'name': 'Nequi', 'type': 'bank', 'currency': 'COP', 'archived': false, 'balance': '1030000'},
      ],
      _ => <dynamic>[],
    };
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });

  Future<void> addExpense(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => state.boot());
    await tester.pumpWidget(quickAddForTest(state));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    for (final k in ['1', '8', '5', '0', '0']) {
      await tester.tap(find.bySemanticsLabel(k));
      await tester.pump();
    }
    expect(find.text('\$ 18.500'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Elegir categoría'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('Sueldo'), findsNothing); // solo las de gasto
    await tester.tap(find.bySemanticsLabel('Transporte'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Guardar gasto'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('anota un gasto en tres toques: monto, categoría y guardar', (tester) async {
    final posted = <Map<String, dynamic>>[];
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: server(posted), baseUrl: 'http://x'),
    );
    await addExpense(tester, state);
    expect(posted.single['type'], 'expense');
    expect(posted.single['amount'], '18500');
    expect(posted.single['category_id'], 'c2');
    expect(posted.single['account_id'], 'n');
    expect(find.textContaining('anotado', findRichText: true), findsOneWidget);
    // La próxima vez Transporte sale primero a esta hora y la cuenta queda recordada
    final usage = CategoryUsage(prefs);
    final sorted = usage.sort([
      Category.fromJson({'id': 'c1', 'name': 'Comida', 'kind': 'expense'}),
      Category.fromJson({'id': 'c2', 'name': 'Transporte', 'kind': 'expense'}),
    ], DateTime.now());
    expect(sorted.first.id, 'c2');
    expect(prefs.getString('quick_account'), 'n');
    await tester.pump(const Duration(seconds: 4)); // se cierra solo
  });

  testWidgets('sin conexión lo guarda para enviarlo después', (tester) async {
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: server([], offline: true), baseUrl: 'http://x'),
    );
    await addExpense(tester, state);
    expect(state.pending.length, 1);
    expect(state.pending.items.single['amount'], '18500');
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
