import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/app_lock.dart';
import 'package:alvea_app/core/csv.dart';
import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/core/notices.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/lock_screen.dart';
import 'package:alvea_app/ui/qr_view.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/gestures.dart';
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

    test('entrar con la contraseña desbloquea sin pedir además el PIN', () async {
      final lock = AppLock(prefs);
      await lock.setPin('2468');
      lock.lock();
      lock.unlock('0000');
      lock.unlockAfterLogin();
      expect(lock.locked, isFalse);
      expect(lock.attemptsLeft, AppLock.maxAttempts);
      expect(lock.enabled, isTrue);
      lock.dispose();
    });

    test('la huella solo cuenta con PIN y se olvida al quitarlo', () async {
      final lock = AppLock(prefs);
      await lock.setUseBiometrics(true);
      expect(lock.useBiometrics, isFalse); // sin PIN no hay bloqueo
      await lock.setPin('2468');
      await lock.setUseBiometrics(true);
      expect(lock.useBiometrics, isTrue);
      lock.lock();
      lock.unlockWithBiometrics();
      expect(lock.locked, isFalse);
      await lock.disable();
      expect(lock.useBiometrics, isFalse);
      lock.dispose();
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

  testWidgets('salir a un diálogo del sistema no bloquea; salir de la app sí', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final lock = AppLock(await SharedPreferences.getInstance());
    await lock.setPin('2468');
    await lock.setDelay(Duration.zero);
    void leaveAndReturn() {
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    // Elegir un archivo o la huella abren una pantalla del sistema encima de la app
    await lock.whileAway(() async => leaveAndReturn());
    expect(lock.locked, isFalse);
    leaveAndReturn();
    expect(lock.locked, isTrue);
    lock.dispose();
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

  testWidgets('con la app bloqueada, la pantalla del PIN ocupa toda la vista y la app queda oculta', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    state.user = User.fromJson({'email': 'ana@example.com', 'full_name': 'Ana Pérez', 'two_factor_enabled': false});
    await state.lock.setPin('2468');
    state.lock.lock();
    // Restricciones holgadas (como dentro del fondo de la app): antes el Stack medía 0×0
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          // Como en la app: por encima del Navigator (sin su Overlay) y con restricciones holgadas
          builder: (context, child) => Center(
            child: LockGate(state: state, child: child!),
          ),
          home: const Text('contenido de la app'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Alvea está bloqueada'), findsOneWidget);
    expect(tester.getSize(find.byType(LockScreen)), tester.view.physicalSize / tester.view.devicePixelRatio);
    expect(find.text('contenido de la app'), findsNothing);

    for (final d in '2468'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    // Los tooltips necesitan un Overlay aunque la pantalla esté por encima del Navigator
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byTooltip('Borrar')));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await gesture.removePointer();
    await tester.tap(find.byTooltip('Desbloquear'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.lock.locked, isFalse);
    expect(find.text('contenido de la app'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
