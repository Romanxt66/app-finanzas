import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/format.dart';
import 'package:alvea_app/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('parseAmount', () {
    test('acepta formatos comunes', () {
      expect(parseAmount('1234.56'), '1234.56');
      expect(parseAmount('1.234,56'), '1234.56');
      expect(parseAmount('1.234.567'), '1234567');
      expect(parseAmount(r'$ 15000'), '15000');
    });
    test('rechaza basura', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('1.2345'), isNull);
    });
  });

  test('fmtMoney usa signo menos y separador de miles', () {
    expect(fmtMoney(12480500), r'$ 12.480.500');
    expect(fmtMoney(-18900), r'− $ 18.900');
    expect(fmtMoney(5, sign: true), r'+ $ 5');
  });

  test('money tolera valores no numéricos', () {
    expect(money('12.50'), 12.5);
    expect(money(null), 0);
  });

  group('ApiClient', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'viejo',
        'refresh_token': 'r1',
      });
      prefs = await SharedPreferences.getInstance();
    });

    test('renueva el token ante un 401 y reintenta', () async {
      final calls = <String>[];
      final client = MockClient((req) async {
        calls.add(
          '${req.method} ${req.url.path} ${req.headers['Authorization'] ?? ''}',
        );
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({'access_token': 'nuevo', 'refresh_token': 'r2'}),
            200,
          );
        }
        return req.headers['Authorization'] == 'Bearer nuevo'
            ? http.Response(jsonEncode({'ok': true}), 200)
            : http.Response('{}', 401);
      });
      final api = ApiClient(prefs, client: client, baseUrl: 'http://x');
      expect(await api.get('/auth/me'), {'ok': true});
      expect(prefs.getString('refresh_token'), 'r2');
      expect(calls.length, 3);
    });

    test('limpia la sesión y avisa si el refresh falla', () async {
      var notified = false;
      final api = ApiClient(
        prefs,
        client: MockClient((_) async => http.Response('{}', 401)),
        baseUrl: 'http://x',
      )..onUnauthorized = () => notified = true;
      await expectLater(api.get('/accounts'), throwsA(isA<ApiError>()));
      expect(notified, isTrue);
      expect(api.hasSession, isFalse);
    });

    test('propaga el mensaje de error de la API', () async {
      final api = ApiClient(
        prefs,
        baseUrl: 'http://x',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'conflict',
                'message': 'Ya existe',
                'details': [],
              },
            }),
            409,
          ),
        ),
      );
      await expectLater(
        api.post('/accounts', body: {}),
        throwsA(
          isA<ApiError>().having((e) => e.message, 'message', 'Ya existe'),
        ),
      );
    });

    test('un fallo de red se traduce a ApiError(0)', () async {
      final api = ApiClient(
        prefs,
        client: MockClient((_) async => throw Exception('sin red')),
        baseUrl: 'http://x',
      );
      await expectLater(
        api.get('/accounts'),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 0)),
      );
    });
  });
}
