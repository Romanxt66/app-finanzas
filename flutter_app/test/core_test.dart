import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/csv.dart';
import 'package:alvea_app/core/format.dart';
import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/core/password.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

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
      expect(parseAmount('-5'), isNull);
    });
    test('permite negativos solo si se pide', () {
      expect(parseAmount('-5', allowNegative: true), '-5');
    });
  });

  group('formatMoney', () {
    test('COP sin decimales, con signo menos tipográfico', () {
      expect(formatMoney(12480500, 'COP'), '\$ 12.480.500');
      expect(formatMoney(-18900, 'COP'), '− \$ 18.900');
      expect(formatMoney(5, 'COP', true), '+ \$ 5');
    });
    test('otras monedas con 2 decimales', () {
      expect(formatMoney(1234.5, 'USD'), 'US\$ 1.234,50');
    });
    test('sin moneda solo el número', () {
      expect(formatMoney(4200000), '4.200.000');
    });
  });

  test('formatHours', () {
    expect(formatHours(0.001), '< 1 min');
    expect(formatHours(0.2), '12 min');
    expect(formatHours(1.5), '1 h 30 min');
    expect(formatHours(26), '26 h');
  });

  test('hourlyRate usa 52 semanas y 12 meses', () {
    expect(hourlyRate(0, 40), isNull);
    expect(hourlyRate(1733.33, 40), closeTo(10, 0.01));
  });

  test('formatDate y monthStart', () {
    expect(formatDate('2026-10-08'), '8 de oct');
    expect(monthStart(DateTime(2026, 10, 23)), '2026-10-01');
  });

  test('money tolera valores no numéricos', () {
    expect(money('12.50'), 12.5);
    expect(money(null), 0);
  });

  group('contraseña', () {
    test('reglas como en el backend', () {
      expect(passwordProblem('abc'), contains('al menos 8'));
      expect(passwordProblem('abcdefgh'), contains('número'));
      expect(passwordProblem('12345678'), contains('letra'));
      expect(passwordProblem('Clave-2026-ok'), isNull);
    });
  });

  group('CSV', () {
    test('detecta el separador y respeta comillas', () {
      expect(detectDelimiter('a;b;c\n1;2;3'), ';');
      expect(parseCsv('a,b\n"x,y",2'), [
        ['a', 'b'],
        ['x,y', '2'],
      ]);
    });
    test('montos con formatos de banco', () {
      expect(parseCsvAmount('1.234,56'), 1234.56);
      expect(parseCsvAmount('1,234.56'), 1234.56);
      expect(parseCsvAmount('(500)'), -500);
      expect(parseCsvAmount('-\$ 1.234'), -1234);
      expect(parseCsvAmount('abc'), isNull);
    });
    test('fechas válidas y formato adivinado', () {
      expect(parseCsvDate('31/12/2026', DateFormatKind.dmy), '2026-12-31');
      expect(parseCsvDate('31/02/2026', DateFormatKind.dmy), isNull);
      expect(guessDateFormat(['25/12/2026']), DateFormatKind.dmy);
      expect(guessDateFormat(['12/25/2026']), DateFormatKind.mdy);
      expect(guessDateFormat(['2026-12-25']), DateFormatKind.ymd);
    });
    test('construye movimientos con signo y reporta errores', () {
      final rows = parseCsv('Fecha;Descripción;Monto\n01/10/2026;Nómina;4.200.000,00\n02/10/2026;Café;-8.500\n32/10/2026;Mal;1');
      final mapping = guessMapping(rows.first, DateFormatKind.dmy);
      final res = buildItems(rows.skip(1).toList(), mapping, 2);
      expect(res.items.map((i) => i.amount), ['4200000.00', '-8500.00']);
      expect(res.errors.single.row, 4);
    });
  });

  group('ApiClient', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'access_token': 'viejo', 'refresh_token': 'r1'});
      prefs = await SharedPreferences.getInstance();
    });

    test('renueva el token ante un 401 y reintenta', () async {
      final calls = <String>[];
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path} ${req.headers['Authorization'] ?? ''}');
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response(jsonEncode({'access_token': 'nuevo', 'refresh_token': 'r2'}), 200);
        }
        return req.headers['Authorization'] == 'Bearer nuevo' ? http.Response(jsonEncode({'ok': true}), 200) : http.Response('{}', 401);
      });
      final api = ApiClient(prefs, client: client, baseUrl: 'http://x');
      expect(await api.get('/auth/me'), {'ok': true});
      expect(prefs.getString('refresh_token'), 'r2');
      expect(calls.length, 3);
    });

    test('limpia la sesión y avisa si el refresh falla', () async {
      var notified = false;
      final api = ApiClient(prefs, client: MockClient((_) async => http.Response('{}', 401)), baseUrl: 'http://x')
        ..onUnauthorized = () => notified = true;
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
              'error': {'code': 'conflict', 'message': 'Ya existe', 'details': []},
            }),
            409,
          ),
        ),
      );
      await expectLater(api.post('/accounts', body: {}), throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Ya existe')));
    });

    test('un fallo de red se traduce a ApiError(0)', () async {
      final api = ApiClient(prefs, client: MockClient((_) async => throw Exception('sin red')), baseUrl: 'http://x');
      await expectLater(api.get('/accounts'), throwsA(isA<ApiError>().having((e) => e.status, 'status', 0)));
    });

    test('sin «mantener sesión» los tokens no se guardan en disco', () async {
      final api = ApiClient(prefs, client: MockClient((_) async => http.Response('{}', 200)), baseUrl: 'http://x');
      await api.saveTokens({'access_token': 'a', 'refresh_token': 'b'}, remember: false);
      expect(prefs.getString('refresh_token'), isNull);
      expect(api.hasSession, isTrue);
      await api.clearTokens();
      expect(api.hasSession, isFalse);
    });
  });
}
