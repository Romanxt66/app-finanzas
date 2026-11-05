import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/goals.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('metas: resumen, filtro de cumplidas y tarjetas', (tester) async {
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient((req) async {
      final body = req.url.path.endsWith('/goals')
          ? [
              {
                'id': 'g1',
                'name': 'Viaje',
                'currency': 'COP',
                'target_amount': '3000',
                'saved': '1000',
                'remaining': '2000',
                'achieved': false,
                'deadline': null,
              },
              {
                'id': 'g2',
                'name': 'Carro',
                'currency': 'COP',
                'target_amount': '500',
                'saved': '500',
                'remaining': '0',
                'achieved': true,
                'deadline': null,
              },
            ]
          : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
    );
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(body: GoalsScreen()),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Carro'), findsOneWidget);
    await tester.tap(find.text('Mostrar metas cumplidas'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Carro'), findsNothing);
    expect(find.text('Viaje'), findsOneWidget);
  });
}
