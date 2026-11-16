import 'package:alvea_app/ui/theme.dart';
import 'package:alvea_app/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.dark),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('sin cambio no muestra «+0 %» como si fuera una mejora', (tester) async {
    await tester.pumpWidget(_app(const Delta(0.01)));
    expect(find.text('Igual'), findsOneWidget);
    expect(find.textContaining('+0'), findsNothing);
  });

  testWidgets('con cambio mantiene signo', (tester) async {
    await tester.pumpWidget(_app(const Delta(-70.2)));
    expect(find.textContaining('−70,2'), findsOneWidget);
  });
}
