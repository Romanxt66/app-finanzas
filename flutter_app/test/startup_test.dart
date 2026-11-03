import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    prefs = await SharedPreferences.getInstance();
  });

  test('las lecturas iguales y seguidas comparten la respuesta; una escritura las descarta', () async {
    var gets = 0;
    final api = ApiClient(
      prefs,
      baseUrl: 'http://x',
      client: MockClient((req) async {
        if (req.method == 'GET') gets++;
        return http.Response(jsonEncode({'n': gets}), 200);
      }),
    );
    final both = await Future.wait([api.get('/accounts'), api.get('/accounts')]);
    expect(gets, 1);
    expect(both[0], both[1]);
    await api.get('/accounts');
    expect(gets, 1);
    await api.get('/categories');
    expect(gets, 2);
    await api.post('/accounts', body: {});
    await api.get('/accounts');
    expect(gets, 3);
  });

  test('un error no se reutiliza', () async {
    var calls = 0;
    final api = ApiClient(
      prefs,
      baseUrl: 'http://x',
      client: MockClient((req) async {
        calls++;
        return calls == 1 ? http.Response('{}', 500) : http.Response('[]', 200);
      }),
    );
    await expectLater(api.get('/accounts'), throwsA(isA<ApiError>()));
    expect(await api.get('/accounts'), isEmpty);
    expect(calls, 2);
  });

  test('con la sesión guardada entra al momento con el último usuario y luego lo confirma', () async {
    final me = {'email': 'ana@example.com', 'full_name': 'Ana', 'two_factor_enabled': false};
    final slow = <Future<void>>[];
    var asked = 0;
    final api = ApiClient(
      prefs,
      baseUrl: 'http://x',
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/me')) {
          asked++;
          final wait = Future<void>.delayed(const Duration(milliseconds: 50));
          slow.add(wait);
          await wait;
          return http.Response.bytes(utf8.encode(jsonEncode({...me, 'full_name': 'Ana María'})), 200);
        }
        return http.Response('[]', 200);
      }),
    );
    await prefs.setString('user_cache', jsonEncode(me));
    final state = AppState(prefs, client: api);
    await state.boot();
    // Ya hay usuario sin esperar al servidor
    expect(state.booting, isFalse);
    expect(state.user?.fullName, 'Ana');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(asked, greaterThanOrEqualTo(1));
    expect(state.user?.fullName, 'Ana María');
    expect(jsonDecode(prefs.getString('user_cache')!)['full_name'], 'Ana María');

    await state.logout();
    expect(prefs.getString('user_cache'), isNull);
  });
}
