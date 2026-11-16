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

  testWidgets('editar una meta envía solo lo que cambió', (tester) async {
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final patches = <Map<String, dynamic>>[];
    const goal = {
      'id': 'g1',
      'name': 'Viaje',
      'currency': 'COP',
      'target_amount': '3000000.00',
      'saved': '0',
      'remaining': '3000000',
      'achieved': false,
      'deadline': null,
    };
    final client = MockClient((req) async {
      if (req.method == 'PATCH') {
        patches.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(goal), 200);
      }
      final body = req.url.path.endsWith('/goals') ? [goal] : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
      quiet: true,
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
    await tester.tap(find.byTooltip('Editar Viaje'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Editar «Viaje»'), findsOneWidget);
    final target = find.widgetWithText(TextField, '3000000');
    expect(target, findsOneWidget);
    await tester.enterText(target, '4000000');
    await tester.tap(find.text('Guardar'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 1));
    expect(patches, [
      {'target_amount': '4000000'},
    ]);
  });
}
