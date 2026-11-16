import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/models.dart';
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

  testWidgets('el historial lista los aportes (el más reciente primero) y borra uno tras confirmar', (tester) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) => d.toString().contains('overflowed') ? null : prev?.call(d);
    addTearDown(() => FlutterError.onError = prev);
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final deleted = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'DELETE') {
        deleted.add(req.url.path);
        return http.Response('', 204);
      }
      final body = req.url.path.endsWith('/contributions')
          ? [
              {'id': 'c1', 'goal_id': 'g1', 'amount': '50000.00', 'occurred_on': '2026-10-01', 'note': 'Prima'},
              {'id': 'c2', 'goal_id': 'g1', 'amount': '-20000.00', 'occurred_on': '2026-11-02', 'note': ''},
            ]
          : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
    );
    final goal = Goal.fromJson({
      'id': 'g1',
      'name': 'Viaje',
      'currency': 'COP',
      'target_amount': '3000000',
      'saved': '30000',
      'remaining': '2970000',
      'achieved': false,
      'deadline': null,
    });
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(body: ContributionHistory(goal: goal)),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Prima'), findsOneWidget);
    // El retiro del 2 de nov va antes que la prima del 1 de oct
    expect(tester.getTopLeft(find.text('2 de nov')).dy, lessThan(tester.getTopLeft(find.text('Prima')).dy));
    await tester.tap(find.byTooltip('Eliminar aporte del 2 de nov').first, warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('Eliminar'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(deleted, ['/api/v1/goals/g1/contributions/c2']);
  });
}
