import 'dart:convert';

import 'package:alvea_app/core/api.dart';
import 'package:alvea_app/core/format.dart';
import 'package:alvea_app/core/reminder_center.dart';
import 'package:alvea_app/core/reminder_scheduler.dart';
import 'package:alvea_app/core/reminders.dart';
import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/reminders.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Programador de mentira: guarda lo que se le pide.
class FakeScheduler implements ReminderScheduler {
  List<PlannedReminder> scheduled = [];
  final shown = <PlannedReminder>[];
  bool granted = true;
  int asked = 0;
  bool cancelled = false;

  @override
  bool get supported => true;
  @override
  Future<void> init(void Function(String route) onOpen) async {}
  @override
  Future<String?> launchRoute() async => null;
  @override
  Future<bool?> permission() async => granted;
  @override
  Future<bool> requestPermission() async {
    asked++;
    return granted;
  }

  @override
  Future<void> schedule(List<PlannedReminder> plan, {required bool hideAmounts}) async => scheduled = plan;
  @override
  Future<void> show(PlannedReminder r, {required bool hideAmounts, bool later = false}) async => shown.add(r);
  @override
  Future<void> cancelAll() async => cancelled = true;
  @override
  Future<void> openSystemSettings() async {}
}

String _iso(DateTime d) => isoDate(d);

http.Client _server(DateTime today) => MockClient((req) async {
  final tomorrow = today.add(const Duration(days: 1));
  final body = switch (req.url.path.replaceFirst('/api/v1', '')) {
    '/recurring' => [
      {
        'id': 'r1',
        'type': 'expense',
        'account_id': 'nequi',
        'transfer_account_id': null,
        'category_id': null,
        'amount': '1150000.00',
        'description': 'Arriendo',
        'frequency': 'monthly',
        'next_date': _iso(today),
        'end_date': null,
        'active': true,
      },
      {
        'id': 'r2',
        'type': 'expense',
        'account_id': 'banco',
        'transfer_account_id': null,
        'category_id': null,
        'amount': '44900.00',
        'description': 'Netflix',
        'frequency': 'monthly',
        'next_date': _iso(tomorrow),
        'end_date': null,
        'active': true,
      },
    ],
    '/accounts' => [
      {'id': 'nequi', 'name': 'Nequi', 'type': 'bank', 'currency': 'COP', 'archived': false, 'balance': '1030000.00'},
      {'id': 'banco', 'name': 'Bancolombia', 'type': 'bank', 'currency': 'COP', 'archived': false, 'balance': '1249200.00'},
    ],
    '/ghost-subscriptions' => {
      'subscriptions': [
        {
          'name': 'Spotify',
          'currency': 'COP',
          'cadence': 'monthly',
          'last_amount': '16900.00',
          'next_expected': _iso(tomorrow),
          'monthly_cost': '16900.00',
          'tracked': false,
        },
      ],
      'alerts': [],
      'untracked_monthly': [],
    },
    '/life-hours/profile' => null,
    _ => null,
  };
  if (body == null) return http.Response(jsonEncode({'detail': 'No encontrado'}), 404);
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('es'));

  late SharedPreferences prefs;
  final today = dayOf(DateTime.now());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('calcula los cobros, los programa y pide permiso una sola vez', () async {
    final scheduler = FakeScheduler()..granted = false;
    final center = ReminderCenter(
      prefs,
      ApiClient(prefs, client: _server(today), baseUrl: 'http://x'),
      scheduler: scheduler,
    );
    await center.refresh();
    expect(center.loaded, isTrue);
    expect(chargesOn(center.charges, today).single.status, ChargeStatus.short);
    expect(center.alert?.name, 'Arriendo');
    expect(center.charges.any((c) => c.name == 'Spotify'), isTrue);
    expect(scheduler.scheduled.every((r) => r.at.isAfter(DateTime.now())), isTrue);
    expect(scheduler.asked, 1);
    await center.refresh();
    expect(scheduler.asked, 1);

    // Sin suscripciones en los ajustes ya no se piden ni se recuerdan
    await center.update(center.settings.copyWith(subscriptions: false));
    expect(center.charges.any((c) => c.detected), isFalse);
    await center.update(center.settings.copyWith(enabled: false));
    expect(scheduler.scheduled, isEmpty);
  });

  test('los registrados hoy quedan como pagados; «Más tarde» oculta el banner; al salir se borra todo', () async {
    final scheduler = FakeScheduler();
    final center = ReminderCenter(
      prefs,
      ApiClient(prefs, client: _server(today), baseUrl: 'http://x'),
      scheduler: scheduler,
    );
    final due = await center.dueToday();
    expect(due.map((c) => c.name), ['Arriendo']);
    await center.markRegistered(due.map((c) => c.copyWith(date: today)).toList());
    // El servidor aún lo trae como de hoy: no se duplica
    await center.refresh();
    expect(chargesOn(center.charges, today).length, 1);

    await center.dismiss(center.alert!);
    expect(center.alert, isNull);

    expect(await center.showTest(), isTrue);
    expect(scheduler.shown.single.id, 1);

    await center.clear();
    expect(scheduler.cancelled, isTrue);
    expect(center.charges, isEmpty);
  });

  Widget app(AppState state, Widget child) => AppScope(
    state: state,
    child: MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('banner «no alcanza», hoja de cobros y ajustes', (tester) async {
    final state = AppState(
      prefs,
      client: ApiClient(prefs, client: _server(today), baseUrl: 'http://x'),
    );
    await tester.runAsync(() => state.reminders.refresh());

    await tester.pumpWidget(app(state, const ChargeAlertBanner()));
    expect(find.text('Arriendo se cobra hoy y no te alcanza'), findsOneWidget);
    expect(find.text('Mover dinero'), findsOneWidget);

    await tester.tap(find.text('Arriendo se cobra hoy y no te alcanza'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lo que se va'), findsOneWidget);
    expect(find.textContaining('Para Arriendo faltan'), findsOneWidget);
    expect(find.text('Hacerla recurrente'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);

    await tester.ensureVisible(find.text('Listo'));
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lo que se va'), findsNothing);
    await tester.tap(find.text('Más tarde'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    expect(find.text('Arriendo se cobra hoy y no te alcanza'), findsNothing);

    await tester.pumpWidget(app(state, const ReminderSettingsCard()));
    expect(find.text('Recordatorios de cobro'), findsOneWidget);
    expect(find.text('Ambos'), findsOneWidget);
    await tester.tap(find.byType(GlassSwitch));
    await tester.pump();
    expect(find.textContaining('Sin recordatorios'), findsOneWidget);
  });
}
