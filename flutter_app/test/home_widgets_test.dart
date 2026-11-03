import 'dart:io';
import 'dart:ui' as ui;

import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/core/reminders.dart';
import 'package:alvea_app/core/widget_sync.dart';
import 'package:alvea_app/ui/accent.dart';
import 'package:alvea_app/ui/charge_ticket.dart';
import 'package:alvea_app/ui/home_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _fonts() async {
  for (final (family, files) in [
    ('Manrope', ['assets/fonts/Manrope.ttf']),
    ('InstrumentSerif', ['assets/fonts/InstrumentSerif-Italic.ttf']),
    ('JetBrainsMono', ['assets/fonts/JetBrainsMono-Regular.ttf']),
  ]) {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(rootBundle.load(f));
    }
    await l.load();
  }
}

Account _acc(String id, String name, String balance) =>
    Account.fromJson({'id': id, 'name': name, 'type': 'bank', 'currency': 'COP', 'archived': false, 'balance': balance});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('es');
    await _fonts();
  });

  final now = DateTime(2026, 11, 16, 9);
  final charges = [
    Charge(
      key: 'a',
      source: ChargeSource.recurring,
      name: 'Arriendo',
      amount: 1150000,
      currency: 'COP',
      date: DateTime(2026, 11, 16),
      frequency: 'monthly',
      accountName: 'Nequi',
      remaining: -120000,
    ),
    Charge(
      key: 'n',
      source: ChargeSource.recurring,
      name: 'Netflix',
      amount: 44900,
      currency: 'COP',
      date: DateTime(2026, 11, 17),
      frequency: 'monthly',
      accountName: 'Bancolombia',
      remaining: 1204300,
    ),
  ];

  HomeWidgetData sample() => buildWidgetData(
    accounts: [_acc('n', 'Nequi', '1030000'), _acc('b', 'Bancolombia', '16151400')],
    summary: Summary.fromJson({
      'month': '2026-11-01',
      'currency': 'COP',
      'currencies': ['COP'],
      'income': '3200000',
      'expense': '1418600',
      'expense_by_category': [],
      'trend': [],
    }),
    allowance: DailyAllowance.fromJson({
      'currency': 'COP',
      'basis': 'budget',
      'pending_committed': '0',
      'days_remaining': 14,
      'average_per_day': '60000',
      'allowance_today': '70000',
      'left_today': '46300',
      'spent_today': '23700',
      'pattern_used': false,
      'status': 'ok',
    }),
    goals: [
      Goal.fromJson({
        'id': 'g',
        'name': 'Viaje a Cartagena',
        'currency': 'COP',
        'target_amount': '3000000',
        'saved': '1920000',
        'remaining': '1080000',
        'achieved': false,
        'deadline': null,
      }),
    ],
    charges: charges,
    now: now,
  );

  test('los datos de los widgets salen de lo que muestra la app', () {
    final d = sample();
    expect(d.balance, '\$ 17.181.400');
    expect(d.todayLeft, '\$ 46.300');
    expect(d.todayOver, isFalse);
    expect(d.todayFraction, closeTo(0.66, 0.01));
    expect(d.charges.first.short, isTrue);
    expect(d.charges.first.when, 'hoy · no alcanza');
    expect(d.charges.last.when, 'mañana · bancolombia');
    expect(d.goal?.progress, closeTo(0.64, 0.001));
    expect(d.moodLine.length, lessThan(36)); // frase corta: cabe en el widget
  });

  testWidgets('cada widget se pinta como imagen', (tester) async {
    final out = Platform.environment['WIDGET_PNG_DIR'];
    await tester.runAsync(() async {
      final d = sample();
      final tint = WidgetTint(fuchsiaAccent);
      for (final kind in HomeWidgetKind.values) {
        final png = await paintToPng(HomeWidgetPainter(kind, d, tint), kind.size * 3);
        final image = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
        expect(image.width, (kind.size.width * 3).round(), reason: kind.name);
        if (out != null) File('$out/w-${kind.name}.png').writeAsBytesSync(png);
      }
      final hidden = await paintToPng(HomeWidgetPainter(HomeWidgetKind.balance, d, tint, hidden: true), HomeWidgetKind.balance.size * 3);
      if (out != null) File('$out/w-balance-hidden.png').writeAsBytesSync(hidden);
    });
  });
}
