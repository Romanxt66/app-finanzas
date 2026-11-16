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

  testWidgets('recurrentes: la lista se ve (no queda transparente) cuando el formulario se pliega al cargar', (tester) async {
    // La fuente de pruebas (cuadros anchos) desborda algún chip: aquí se mide la visibilidad, no eso
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('overflowed')) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/recurring')) await Future<void>.delayed(const Duration(milliseconds: 200));
      final body = req.url.path.endsWith('/recurring')
          ? jsonDecode(
              r'''[{"id":"eb8bdb8c-349a-4f26-a9b2-bdcf2d216b4c","created_at":"2026-11-06T19:15:29","type":"expense","account_id":"5b2ee82a-55d9-428b-bdcf-c55ce344f13a","transfer_account_id":null,"category_id":null,"amount":"16900.00","description":"Spotify","frequency":"monthly","next_date":"2026-12-07","end_date":null,"active":true}]''',
            )
          : <dynamic>[];
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: client, baseUrl: 'http://x'),
      quiet: true,
    );
    final accounts = [
      for (final a in jsonDecode(
        r'''[{"id":"5b2ee82a-55d9-428b-bdcf-c55ce344f13a","created_at":"2026-11-06T19:15:28","name":"Banco","type":"bank","currency":"COP","initial_balance":"2500000.00","archived":false,"balance":"18176500.00"},{"id":"d4448c90-2ee4-4e9d-8ef4-c1e645b58786","created_at":"2026-11-06T19:15:28","name":"Caja","type":"bank","currency":"COP","initial_balance":"180000.00","archived":false,"balance":"-920000.00"}]''',
      ) as List)
        Account.fromJson(a as Map<String, dynamic>),
    ];
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: RefScope(
          ref: RefData(accounts: accounts, allAccounts: accounts, loaded: true),
          child: MaterialApp(
            theme: buildTheme(Brightness.dark),
            home: const Scaffold(body: RecurringScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    // Llegan los datos con el formulario abierto (sin datos aún) y la lista fuera de la vista
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Spotify'), findsOneWidget);
    // find.text encuentra también lo transparente: se mira la opacidad real de su módulo
    final opacities = tester.widgetList<Opacity>(find.ancestor(of: find.text('Spotify'), matching: find.byType(Opacity)));
    expect(opacities.every((o) => o.opacity > 0.99), isTrue, reason: 'la lista quedó invisible');
  });
}
