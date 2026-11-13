import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppState, List<String>, SharedPreferences)> start(String owner) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'a',
      'refresh_token': 'r',
      'offline_owner': owner,
      'offline_outbox': jsonEncode([
        {
          'id': '1',
          'method': 'POST',
          'path': '/transactions',
          'body': {'amount': '5'},
          'created_at': '2026-11-13T00:00:00Z',
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final writes = <String>[];
    final api = ApiClient(
      prefs,
      baseUrl: 'http://x',
      client: MockClient((req) async {
        if (req.method != 'GET') writes.add('${req.method} ${req.url.path}');
        if (req.url.path.endsWith('/auth/me')) {
          return http.Response(jsonEncode({'email': 'luis@example.com', 'full_name': 'Luis', 'two_factor_enabled': false}), 200);
        }
        if (req.method == 'POST') return http.Response(jsonEncode({'id': 'real-1'}), 201);
        return http.Response('[]', 200);
      }),
    );
    final state = AppState(prefs, client: api);
    await state.boot();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return (state, writes, prefs);
  }

  test('los cambios sin conexión de otra cuenta se descartan y nunca se envían con la sesión nueva', () async {
    final (state, writes, prefs) = await start('ana@example.com');
    expect(writes.where((w) => w.contains('/transactions')), isEmpty);
    expect(state.api.outbox.isEmpty, isTrue);
    expect(prefs.getString('offline_owner'), 'luis@example.com');
  });

  test('los de la misma cuenta sí se envían al entrar', () async {
    final (state, writes, _) = await start('luis@example.com');
    expect(writes.where((w) => w.contains('/transactions')), hasLength(1));
    expect(state.api.outbox.isEmpty, isTrue);
  });
}
