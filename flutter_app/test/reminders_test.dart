import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/core/reminders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Account account(String id, String name, String balance, {String type = 'bank', String currency = 'COP'}) =>
    Account.fromJson({'id': id, 'name': name, 'type': type, 'currency': currency, 'archived': false, 'balance': balance});

Recurring rule(
  String id,
  String description,
  String amount,
  String nextDate, {
  String account = 'nequi',
  String type = 'expense',
  String frequency = 'monthly',
  String? to,
  String? endDate,
  bool active = true,
}) => Recurring.fromJson({
  'id': id,
  'type': type,
  'account_id': account,
  'transfer_account_id': to,
  'category_id': null,
  'amount': amount,
  'description': description,
  'frequency': frequency,
  'next_date': nextDate,
  'end_date': endDate,
  'active': active,
});

Subscription sub(String name, String amount, String next, {bool tracked = false}) => Subscription.fromJson({
  'name': name,
  'currency': 'COP',
  'cadence': 'monthly',
  'last_amount': amount,
  'next_expected': next,
  'monthly_cost': amount,
  'tracked': tracked,
});

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  // Lunes 16 de noviembre de 2026
  final monday = DateTime(2026, 11, 16);
  final accounts = [account('nequi', 'Nequi', '1030000'), account('bancolombia', 'Bancolombia', '1249200')];

  group('projectCharges', () {
    test('calcula si alcanza en cada cuenta', () {
      final charges = projectCharges(
        rules: [
          rule('r1', 'Arriendo', '1150000', '2026-11-16'),
          rule('r2', 'Netflix', '44900', '2026-11-16', account: 'bancolombia'),
        ],
        accounts: accounts,
        today: monday,
        horizonDays: 7,
      );
      expect(charges.map((c) => c.name), ['Arriendo', 'Netflix']);
      final rent = charges.first;
      expect(rent.status, ChargeStatus.short);
      expect(rent.shortfall, 120000);
      expect(rent.accountName, 'Nequi');
      expect(charges.last.status, ChargeStatus.covered);
      expect(charges.last.remaining, 1204300);
    });

    test('suma los ingresos del mismo día antes de los cobros y resta los anteriores', () {
      final charges = projectCharges(
        rules: [
          rule('salary', 'Sueldo', '500000', '2026-11-20', type: 'income'),
          rule('gym', 'Gimnasio', '32800', '2026-11-18'),
          rule('rent', 'Arriendo', '1150000', '2026-11-20'),
        ],
        accounts: accounts,
        today: monday,
      );
      final rent = charges.firstWhere((c) => c.name == 'Arriendo');
      expect(rent.remaining, 1030000 - 32800 + 500000 - 1150000);
      expect(rent.status, ChargeStatus.covered);
    });

    test('una transferencia saca de una cuenta y entra en la otra', () {
      final charges = projectCharges(
        rules: [
          rule('t', 'Ahorro', '1000000', '2026-11-17', type: 'transfer', to: 'bancolombia'),
          rule('n', 'Luz', '100000', '2026-11-18'),
          rule('b', 'Seguro', '2000000', '2026-11-18', account: 'bancolombia'),
        ],
        accounts: accounts,
        today: monday,
      );
      expect(charges.firstWhere((c) => c.name == 'Luz').remaining, 1030000 - 1000000 - 100000);
      expect(charges.firstWhere((c) => c.name == 'Seguro').remaining, 1249200 + 1000000 - 2000000);
    });

    test('repite las semanales y respeta la fecha final', () {
      final charges = projectCharges(
        rules: [rule('w', 'Clases', '20000', '2026-11-17', frequency: 'weekly', endDate: '2026-12-01')],
        accounts: accounts,
        today: monday,
      );
      expect(charges.map((c) => c.date), [DateTime(2026, 11, 17), DateTime(2026, 11, 24), DateTime(2026, 12, 1)]);
      expect(charges.map((c) => c.key).toSet().length, 3);
    });

    test('los vencidos sin registrar cuentan como de hoy; los pausados no', () {
      final charges = projectCharges(
        rules: [rule('old', 'Internet', '90000', '2026-11-10'), rule('off', 'Pausado', '1000', '2026-11-17', active: false)],
        accounts: accounts,
        today: monday,
        horizonDays: 7,
      );
      expect(charges.single.date, monday);
      expect(charges.single.name, 'Internet');
    });

    test('suscripciones detectadas sin registrar, dentro del horizonte', () {
      final charges = projectCharges(
        rules: const [],
        accounts: accounts,
        subscriptions: [
          sub('Spotify', '16900', '2026-11-17'),
          sub('Disney', '38900', '2026-11-18', tracked: true),
          sub('Antigua', '10000', '2026-11-01'),
          sub('Lejana', '10000', '2027-02-01'),
        ],
        today: monday,
      );
      expect(charges.single.name, 'Spotify');
      expect(charges.single.status, ChargeStatus.unknown);
      expect(charges.single.detected, isTrue);
    });

    test('en una tarjeta de crédito no se juzga si alcanza', () {
      final charges = projectCharges(
        rules: [rule('c', 'Seguro', '50000', '2026-11-17', account: 'card')],
        accounts: [account('card', 'Visa', '-300000', type: 'card')],
        today: monday,
        horizonDays: 7,
      );
      expect(charges.single.status, ChargeStatus.unknown);
    });
  });

  test('nextOccurrence recorta los meses cortos sin perder el día', () {
    final feb = nextOccurrence(DateTime(2026, 1, 31), 'monthly', 31);
    expect(feb, DateTime(2026, 2, 28));
    expect(nextOccurrence(feb, 'monthly', 31), DateTime(2026, 3, 31));
    expect(nextOccurrence(DateTime(2028, 2, 29), 'yearly', 29), DateTime(2029, 2, 28));
    expect(nextOccurrence(DateTime(2026, 10, 30), 'weekly', 30), DateTime(2026, 11, 6));
  });

  test('withRegistered marca como pagados los de hoy que ya se registraron', () {
    final netflix = Charge(
      key: 'r:r2:2026-11-16',
      source: ChargeSource.recurring,
      name: 'Netflix',
      amount: 44900,
      currency: 'COP',
      date: monday,
      frequency: 'monthly',
      ruleId: 'r2',
      accountId: 'bancolombia',
      accountName: 'Bancolombia',
    );
    final yesterday = netflix.copyWith(date: DateTime(2026, 11, 15));
    final out = withRegistered(
      const [],
      [netflix, yesterday],
      rules: [rule('r2', 'Netflix', '44900', '2026-12-16', account: 'bancolombia')],
      accounts: accounts,
      today: monday,
    );
    expect(out.single.status, ChargeStatus.paid);
    expect(out.single.remaining, 1249200);
    expect(out.single.nextDate, DateTime(2026, 12, 16));
    // Si la proyección aún lo trae, no se duplica
    expect(withRegistered([netflix], [netflix], rules: const [], accounts: accounts, today: monday).length, 1);
  });

  group('planReminders', () {
    final charges = projectCharges(
      rules: [rule('r2', 'Netflix', '44900', '2026-11-16', account: 'bancolombia')],
      accounts: accounts,
      today: DateTime(2026, 11, 15),
      horizonDays: 7,
    );

    test('el día antes y el mismo día, a la hora elegida', () {
      final plan = planReminders(charges, const ReminderSettings(), now: DateTime(2026, 11, 15, 7));
      expect(plan.map((r) => r.at), [DateTime(2026, 11, 15, 9), DateTime(2026, 11, 16, 9)]);
      expect(plan.map((r) => r.id), [1000, 1001]);
      expect(plan.first.title, 'Mañana se cobra Netflix');
      expect(plan.last.title, 'Hoy se cobra Netflix');
      expect(plan.first.route, '/?cobros=2026-11-16');
      expect(plan.first.ticket!.accent, 'mañana');
      expect(plan.first.moveRoute, isNull);
    });

    test('no programa avisos en el pasado ni si están apagados', () {
      expect(planReminders(charges, const ReminderSettings(), now: DateTime(2026, 11, 15, 10)).length, 1);
      expect(planReminders(charges, const ReminderSettings(enabled: false), now: DateTime(2026, 11, 15, 7)), isEmpty);
      final evening = planReminders(
        charges,
        const ReminderSettings(when: ReminderWhen.dayBefore, hour: 18),
        now: DateTime(2026, 11, 15, 10),
      );
      expect(evening.single.at, DateTime(2026, 11, 15, 18));
    });

    test('respeta qué recordar', () {
      final subs = projectCharges(
        rules: const [],
        accounts: accounts,
        subscriptions: [sub('Spotify', '16900', '2026-11-17')],
        today: monday,
      );
      expect(planReminders(subs, const ReminderSettings(subscriptions: false), now: monday), isEmpty);
      expect(planReminders(subs, const ReminderSettings(), now: monday).length, 2);
      expect(planReminders(charges, const ReminderSettings(recurring: false), now: DateTime(2026, 11, 15)), isEmpty);
    });

    test('resumen de la semana los lunes con dos cobros o más', () {
      final week = projectCharges(
        rules: [
          rule('a', 'Arriendo', '1150000', '2026-11-16'),
          rule('n', 'Netflix', '44900', '2026-11-16', account: 'bancolombia'),
          rule('g', 'Gimnasio', '32800', '2026-11-21', account: 'bancolombia'),
        ],
        accounts: accounts,
        today: DateTime(2026, 11, 15),
        horizonDays: 7,
      );
      final plan = planReminders(week, const ReminderSettings(when: ReminderWhen.sameDay), now: DateTime(2026, 11, 15, 20));
      final summary = plan.firstWhere((r) => r.charge == null);
      expect(summary.at, DateTime(2026, 11, 16, 9));
      expect(summary.title, 'Esta semana: 3 cobros por 1.227.700 COP');
      expect(summary.lines.first, 'Arriendo · hoy: 1.150.000 COP');
      expect(summary.lines.last, 'Gimnasio · el sábado: 32.800 COP');
      final rent = plan.firstWhere((r) => r.charge?.name == 'Arriendo');
      expect(rent.alert, isTrue);
      expect(rent.title, 'Hoy se cobra Arriendo y no alcanza');
      expect(rent.moveRoute, '/transactions?mover=nequi&monto=120000&nota=Para+cubrir+Arriendo');
    });
  });

  group('textos', () {
    final netflix = projectCharges(
      rules: [rule('r2', 'Netflix', '44900', '2026-11-16', account: 'bancolombia')],
      accounts: accounts,
      today: DateTime(2026, 11, 15),
    ).first;

    test('cuerpo del aviso con horas de trabajo', () {
      expect(
        chargeBody(netflix, DateTime(2026, 11, 15), hourlyRate: 20723),
        '44.900 COP de Bancolombia. Te quedarán 1.204.300 COP. Equivale a unas 2 h 10 min de tu trabajo.',
      );
      expect(chargeBody(netflix, DateTime(2026, 11, 15)), '44.900 COP de Bancolombia. Te quedarán 1.204.300 COP.');
    });

    test('tarjeta de cobro en sus tres estados', () {
      final covered = ticketFor(netflix, DateTime(2026, 11, 15));
      expect(covered.variant, TicketVariant.covered);
      expect([covered.lead, covered.accent, covered.amount, covered.currency], ['Se cobra', 'mañana', '\$\u00a044.900', 'COP']);
      expect([covered.weekday, covered.day, covered.month], ['lunes', '16', 'nov']);
      expect(covered.meta, 'bancolombia · cada mes');
      expect(covered.chip, 'te quedarán \$\u00a01.204.300');
      expect(covered.initial, 'N');

      final short = ticketFor(netflix.copyWith(remaining: -120000), monday);
      expect([short.variant, short.lead, short.accent, short.weekday], [TicketVariant.short, 'Hoy se cobra', 'y no alcanza', 'hoy']);
      expect(short.chip, 'te faltan \$\u00a0120.000');
      expect(short.chipTone, ChipTone.bad);

      final paid = ticketFor(netflix.copyWith(paid: true, nextDate: DateTime(2026, 12, 16)), monday);
      expect(
        [paid.variant, paid.lead, paid.accent, paid.weekday, paid.chip],
        [TicketVariant.paid, 'Listo,', 'registrado', 'pagado', 'próximo cobro: 16 dic'],
      );
      expect(paid.signature, isNot(covered.signature));
    });

    test('lo que dice Alvi y el encabezado del día', () {
      final today = chargesOn(
        projectCharges(
          rules: [
            rule('r1', 'Arriendo', '1150000', '2026-11-16'),
            rule('r2', 'Netflix', '44900', '2026-11-16', account: 'bancolombia'),
          ],
          accounts: accounts,
          today: monday,
        ),
        monday,
      );
      expect(
        alviLine(today, accounts, isToday: true),
        'Netflix está cubierto, pero para Arriendo faltan \$\u00a0120.000. ¿Los pasamos desde Bancolombia?',
      );
      expect(dayHeading(monday, today), 'lunes 16 nov · 2 cobros · \$\u00a01.194.900');
      expect(alviLine(const [], accounts, isToday: true), 'Hoy no se cobra nada. ¡Día tranquilo!');
      expect(alertCharge(today, monday)?.name, 'Arriendo');
      expect(alertCharge(today, DateTime(2026, 11, 18)), isNull);
    });
  });

  group('ReminderSettings', () {
    test('valores por defecto y guardado', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(ReminderSettings.load(prefs), const ReminderSettings());
      const custom = ReminderSettings(enabled: false, when: ReminderWhen.dayBefore, hour: 18, subscriptions: false, hideAmounts: true);
      await custom.save(prefs);
      expect(ReminderSettings.load(prefs), custom);
      expect(custom.sameDay, isFalse);
      expect(custom.dayBefore, isTrue);
    });

    test('ignora valores raros', () {
      final s = ReminderSettings.fromJson({'when': 'nunca', 'hour': 3});
      expect(s.when, ReminderWhen.both);
      expect(s.hour, 9);
      expect(s.enabled, isTrue);
    });

    test('hourLabel', () {
      expect(hourLabel(8), '8 a. m.');
      expect(hourLabel(18), '6 p. m.');
      expect(hourLabel(12), '12 p. m.');
    });
  });
}
