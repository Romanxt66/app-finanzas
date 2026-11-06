import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'});
    prefs = await SharedPreferences.getInstance();
    ApiClient.retryDelays = const [Duration(milliseconds: 1), Duration(milliseconds: 1)];
  });

  test('una lectura que falla por un momento se reintenta y no deja aviso', () async {
    var calls = 0;
    final api = ApiClient(
      prefs,
      baseUrl: 'http://x',
      client: MockClient((req) async {
        calls++;
        if (calls == 1) throw Exception('sin red');
        if (calls == 2) return http.Response('', 503);
        return http.Response(
          jsonEncode([
            {'id': 'a'},
          ]),
          200,
        );
      }),
    );
    expect(await api.get('/accounts'), [
      {'id': 'a'},
    ]);
    expect(calls, 3);
    expect(api.loadError.value, isNull);
  });

  test('si el servidor sigue caído, avisa (loadError) y al volver se limpia', () async {
    var up = false;
    final api = ApiClient(
      prefs,
      baseUrl: 'http://x',
      client: MockClient((req) async => up ? http.Response('[]', 200) : http.Response('', 502)),
    );
    await expectLater(api.get('/accounts'), throwsA(isA<ApiError>()));
    expect(api.loadError.value?.status, 502);
    up = true;
    await Future<void>.delayed(const Duration(seconds: 3)); // pasa la ventana de reutilización
    await api.get('/accounts');
    expect(api.loadError.value, isNull);
  });

  test('las escrituras no se repiten', () async {
    var calls = 0;
    final api = ApiClient(
      prefs,
      baseUrl: 'http://x',
      client: MockClient((req) async {
        calls++;
        return http.Response('', 503);
      }),
    );
    await expectLater(api.post('/transactions', body: {}), throwsA(isA<ApiError>()));
    expect(calls, 1);
    expect(api.loadError.value, isNull);
  });
}
