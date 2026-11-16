import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/profile.dart';
import 'package:alvea_app/ui/buttons.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('«Guardar» del nombre solo se activa si el nombre cambió', (tester) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) => d.toString().contains('overflowed') ? null : prev?.call(d);
    addTearDown(() => FlutterError.onError = prev);
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient((req) async {
      final body = req.url.path.endsWith('/auth/me')
          ? {'id': 'u1', 'email': 'ana@example.com', 'full_name': 'Ana', 'two_factor_enabled': false}
          : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
    );
    await tester.runAsync(state.reloadUser);
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    CrButton save() => tester.widget<CrButton>(find.widgetWithText(CrButton, 'Guardar').first);
    expect(save().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Ana').first, 'Ana María');
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });
}
