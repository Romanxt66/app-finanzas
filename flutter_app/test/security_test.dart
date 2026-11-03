import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/app_lock.dart';
import 'package:alvea_app/core/csv.dart';
import 'package:alvea_app/core/notices.dart';
import 'package:alvea_app/ui/qr_view.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PIN', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('solo acepta de 4 a 6 dígitos', () {
      expect(AppLock.validPin('1234'), isTrue);
      expect(AppLock.validPin('123456'), isTrue);
      expect(AppLock.validPin('123'), isFalse);
      expect(AppLock.validPin('1234567'), isFalse);
      expect(AppLock.validPin('12a4'), isFalse);
    });

    test('guarda un hash con sal, nunca el PIN, y desbloquea con el correcto', () async {
      final lock = AppLock(prefs);
      expect(lock.enabled, isFalse);
      await lock.setPin('2468');
      expect(lock.enabled, isTrue);
      expect(prefs.getString('pin_hash'), isNot(contains('2468')));
      lock.lock();
      expect(lock.locked, isTrue);
      expect(lock.unlock('1111'), isFalse);
      expect(lock.attemptsLeft, AppLock.maxAttempts - 1);
      expect(lock.unlock('2468'), isTrue);
      expect(lock.locked, isFalse);
      expect(lock.attemptsLeft, AppLock.maxAttempts);
      lock.dispose();
    });

    test('al abrir la app con PIN empieza bloqueada', () async {
      final first = AppLock(prefs);
      await first.setPin('2468');
      first.dispose();
      final reopened = AppLock(prefs);
      expect(reopened.locked, isTrue);
      reopened.dispose();
    });

    test('demasiados intentos avisan para cerrar la sesión', () async {
      final lock = AppLock(prefs);
      await lock.setPin('2468');
      var out = 0;
      lock.onTooManyAttempts = () => out++;
      for (var i = 0; i < AppLock.maxAttempts; i++) {
        lock.unlock('0000');
      }
      expect(out, 1);
      lock.dispose();
    });
  });

  group('importación', () {
    test('encuentra el encabezado tras las filas de datos de la cuenta', () {
      final rows = parseCsv(
        'Banco;Bancolombia\nCuenta;****1234\nDesde;01/10/2026\n'
        'FECHA;DESCRIPCIÓN;SUCURSAL;VALOR;SALDO\n02/10/2026;COMPRA EXITO;Bogotá;-120.000,00;880.000,00\n',
        ';',
      );
      final header = findHeaderRow(rows);
      expect(header, 3);
      final mapping = guessMapping(rows[header], DateFormatKind.dmy);
      expect((mapping.date, mapping.description, mapping.amount), (0, 1, 3));
      final parsed = buildItems(rows.sublist(header + 1), mapping, header + 2);
      expect(parsed.items.single.amount, '-120000.00');
    });

    test('sin filas previas, el encabezado es la primera fila (o no hay)', () {
      expect(findHeaderRow(parseCsv('Fecha,Concepto,Importe\n2026-01-01,Café,-5', ',')), 0);
      expect(findHeaderRow(parseCsv('2026-01-01,Café,-5', ',')), -1);
    });

    test('agrupa por descripción (sin mayúsculas) y signo', () {
      const a = ImportItem('2026-01-01', 'NETFLIX.COM ', '-44900.00');
      const b = ImportItem('2026-02-01', 'netflix.com', '-44900.00');
      const refund = ImportItem('2026-02-03', 'Netflix.com', '44900.00');
      expect(categoryGroupKey(a), categoryGroupKey(b));
      expect(categoryGroupKey(a), isNot(categoryGroupKey(refund)));
    });
  });

  group('avisos', () {
    Future<NoticeCenter> center(List<Map<String, dynamic>> items) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = MockClient((req) async {
        expect(req.url.path, '/api/v1/notifications');
        return http.Response(jsonEncode({'items': items}), 200, headers: {'content-type': 'application/json'});
      });
      return NoticeCenter(prefs, ApiClient(prefs, client: client, baseUrl: 'http://x'));
    }

    Map<String, dynamic> notice(String id, String severity) => {
      'id': id,
      'kind': 'budget_warning',
      'severity': severity,
      'title': 'Título $id',
      'body': 'Cuerpo',
      'link': '/budgets',
      'date': '2026-11-03',
    };

    test('cuenta los no leídos y recuerda los leídos', () async {
      final c = await center([notice('a', 'danger'), notice('b', 'info')]);
      await c.load();
      expect(c.unread, 2);
      expect(c.top!.id, 'a');
      await c.markRead(c.items.first);
      expect(c.unread, 1);
      expect(c.top!.id, 'b');
      await c.markAllRead();
      expect(c.unread, 0);
      expect(c.top, isNull);
    });

    test('fuera del navegador no hay avisos del sistema', () {
      expect(NoticeCenter.browserPermission, 'unsupported');
    });
  });

  testWidgets('el código QR se dibuja sobre blanco', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: const Scaffold(body: Center(child: QrView('otpauth://totp/Alvea:ana%40example.com?secret=ABC', size: 180))),
      ),
    );
    expect(find.bySemanticsLabel('Código QR'), findsOneWidget);
    expect(tester.getSize(find.byType(QrView)), const Size(180, 180));
  });
}
