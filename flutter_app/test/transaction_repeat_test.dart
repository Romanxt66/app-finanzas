import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/core/reference.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/transactions.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('«Repetir hoy» abre un alta con los mismos datos y la fecha de hoy', (tester) async {
    // La fuente de pruebas (cuadros anchos) desborda algún chip; aquí se mira lo que se envía
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('overflowed')) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final posted = <Map<String, dynamic>>[];
    const tx = {
      'id': 't1',
      'type': 'expense',
      'account_id': 'a1',
      'transfer_account_id': null,
      'category_id': 'c1',
      'amount': '18000.00',
      'description': 'Café',
      'occurred_on': '2026-11-01',
    };
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/transactions')) {
        posted.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({...tx, 'id': 't2'}), 201);
      }
      final path = req.url.path;
      final Object body = path.endsWith('/transactions')
          ? {
              'items': [tx],
              'total': 1,
            }
          : path.endsWith('/summary')
          ? {'income': '0', 'expense': '0', 'net': '0', 'currency': 'COP', 'expense_by_category': <dynamic>[], 'trend': <dynamic>[]}
          : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
      quiet: true,
    );
    final account = Account.fromJson({'id': 'a1', 'name': 'Banco', 'type': 'bank', 'currency': 'COP', 'archived': false, 'balance': '0'});
    tester.view.physicalSize = const Size(900 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: RefScope(
          ref: RefData(accounts: [account], allAccounts: [account], loaded: true),
          child: MaterialApp(
            theme: buildTheme(Brightness.dark),
            home: const Scaffold(body: TransactionsScreen()),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Repetir hoy').first);
    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(TextField, '18000'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Café'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 1));
    expect(posted, hasLength(1));
    expect(posted.single, containsPair('account_id', 'a1'));
    expect(posted.single, containsPair('category_id', 'c1'));
    expect(posted.single, containsPair('description', 'Café'));
    expect(posted.single['occurred_on'], isNot('2026-11-01'));
  });
}
