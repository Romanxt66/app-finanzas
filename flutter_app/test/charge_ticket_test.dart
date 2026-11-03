import 'dart:io';
import 'dart:ui' as ui;

import 'package:alvea_app/core/reminders.dart';
import 'package:alvea_app/ui/charge_ticket.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Carga las fuentes de la app para que la tarjeta se pinte con su tipografía real.
Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Manrope', ['assets/fonts/Manrope.ttf']),
    ('InstrumentSerif', ['assets/fonts/InstrumentSerif-Italic.ttf']),
    ('JetBrainsMono', ['assets/fonts/JetBrainsMono-Regular.ttf', 'assets/fonts/JetBrainsMono-Medium.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('es');
    await _loadFonts();
  });

  final netflix = Charge(
    key: 'r:n:2026-11-16',
    source: ChargeSource.recurring,
    name: 'Netflix',
    amount: 44900,
    currency: 'COP',
    date: DateTime(2026, 11, 16),
    frequency: 'monthly',
    accountId: 'b',
    accountName: 'Bancolombia',
    remaining: 1204300,
  );
  final rent = Charge(
    key: 'r:a:2026-11-16',
    source: ChargeSource.recurring,
    name: 'Arriendo',
    amount: 1150000,
    currency: 'COP',
    date: DateTime(2026, 11, 16),
    frequency: 'monthly',
    accountId: 'n',
    accountName: 'Nequi',
    remaining: -120000,
  );

  testWidgets('la tarjeta de cobro se pinta como imagen en sus tres estados', (tester) async {
    final out = Platform.environment['TICKET_PNG_DIR'];
    await tester.runAsync(() async {
      final background = await loadTicketBackground();
      expect(background, isNotNull);
      final tickets = {
        'alcanza': ticketFor(netflix, DateTime(2026, 11, 15)),
        'no-alcanza': ticketFor(rent, DateTime(2026, 11, 16)),
        'pagado': ticketFor(netflix.copyWith(paid: true, nextDate: DateTime(2026, 12, 16)), DateTime(2026, 11, 16)),
      };
      for (final MapEntry(key: name, value: data) in tickets.entries) {
        final png = await paintToPng(ChargeTicketPainter(data, background: background), ticketSize);
        final codec = await ui.instantiateImageCodec(png);
        final image = (await codec.getNextFrame()).image;
        expect([image.width, image.height], [960, 480], reason: name);
        // Pesa poco: se guarda una por aviso en el teléfono
        expect(png.length, lessThan(900 * 1024), reason: name);
        if (out != null) File('$out/ticket-$name.png').writeAsBytesSync(png);
      }
      for (final v in TicketVariant.values) {
        final png = await paintToPng(AlviBubblePainter(v), const Size.square(192));
        expect(png.length, greaterThan(1000));
        if (out != null) File('$out/bubble-${v.name}.png').writeAsBytesSync(png);
      }
    });
  });

  test('cssLinear sigue el ángulo de CSS', () {
    // 90° va de izquierda a derecha por el centro
    final g = cssLinear(const Rect.fromLTWH(0, 0, 100, 50), 90, const [Color(0xFF000000), Color(0xFFFFFFFF)], const [0, 1]);
    expect(g, isA<ui.Gradient>());
  });
}
