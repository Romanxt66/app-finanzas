import 'package:alvea_app/ui/motion.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:alvea_app/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

bool _hasStripes(WidgetTester t) => t.widgetList<CustomPaint>(find.byType(CustomPaint)).any((p) => p.painter is StripesPainter);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('un presupuesto excedido lleva la barra rayada (no solo un color)', (tester) async {
    await tester.pumpWidget(_app(const BudgetBar(label: 'Ocio', spent: 210, limit: 150)));
    await tester.pumpAndSettle();
    expect(_hasStripes(tester), isTrue);
  });

  testWidgets('dentro del límite la barra es lisa', (tester) async {
    await tester.pumpWidget(_app(const BudgetBar(label: 'Comida', spent: 50, limit: 150)));
    await tester.pumpAndSettle();
    expect(_hasStripes(tester), isFalse);
  });
}
