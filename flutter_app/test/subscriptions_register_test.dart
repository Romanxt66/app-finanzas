import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/subscriptions.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _sub({String? accountId}) => {
  'name': 'Netflix',
  'currency': 'COP',
  'cadence': 'monthly',
  'typical_amount': '44900.00',
  'last_amount': '44900.00',
  'last_date': '2026-11-05',
  'next_expected': '2026-12-05',
  'occurrences': 4,
  'monthly_cost': '44900.00',
  'account_id': accountId,
  'category_id': 'c9',
  'tracked': false,
};

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<List<Map<String, dynamic>>> pump(WidgetTester tester, Map<String, dynamic> sub) async {
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final posted = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/recurring')) {
        posted.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('{}', 201);
      }
      final body = req.url.path.endsWith('/ghost-subscriptions')
          ? {
              'subscriptions': [sub],
              'alerts': <dynamic>[],
              'untracked_monthly': <dynamic>[],
            }
          : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
      quiet: true,
    );
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(body: SubscriptionsScreen()),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 2));
    return posted;
  }

  testWidgets('un cobro sin registrar se registra como recurrente con un toque', (tester) async {
    final posted = await pump(tester, _sub(accountId: 'a1'));
    expect(find.text('Netflix'), findsOneWidget);
    await tester.tap(find.text('Registrar'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 1));
    expect(posted, [
      {
        'type': 'expense',
        'account_id': 'a1',
        'category_id': 'c9',
        'amount': '44900.00',
        'description': 'Netflix',
        'frequency': 'monthly',
        'start_date': '2026-12-05',
      },
    ]);
  });

  testWidgets('sin la cuenta (servidor anterior) solo muestra la etiqueta', (tester) async {
    await pump(tester, _sub());
    expect(find.text('Registrar'), findsNothing);
    expect(find.text('Sin registrar'), findsWidgets);
  });
}
