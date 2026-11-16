import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/core/reference.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/recurring.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('recurrentes: lista y resumen de lo fijo al mes', (tester) async {
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient((req) async {
      final body = req.url.path.endsWith('/recurring')
          ? [
              {
                'id': 'r1',
                'type': 'expense',
                'account_id': 'a1',
                'category_id': null,
                'amount': '16900.00',
                'description': 'Spotify',
                'frequency': 'monthly',
                'next_date': '2026-12-07',
                'transfer_account_id': null,
                'end_date': null,
                'active': true,
              },
            ]
          : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
      quiet: true,
    );
    final account = Account.fromJson({
      'id': 'a1',
      'name': 'Banco',
      'type': 'bank',
      'currency': 'COP',
      'balance': '0',
      'initial_balance': '0',
      'archived': false,
      'created_at': '2026-01-01T00:00:00Z',
    });
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: RefScope(
          ref: RefData(accounts: [account], allAccounts: [account], loaded: true),
          child: MaterialApp(
            theme: buildTheme(Brightness.dark),
            home: const Scaffold(body: RecurringScreen()),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('fijos al mes'), findsWidgets);
  });
}
