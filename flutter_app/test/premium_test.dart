import 'package:alvea_app/ui/dialogs.dart';
import 'package:alvea_app/ui/page.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.dark),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('un aviso con «Deshacer» recibe el toque y se cierra', (tester) async {
    final toasts = ToastController();
    var undone = 0;
    await tester.pumpWidget(_app(ToastHost(controller: toasts, child: const SizedBox.expand())));
    toasts.show('Movimiento eliminado', actionLabel: 'Deshacer', onAction: () => undone++);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Movimiento eliminado'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(undone, 1);
    expect(toasts.items, isEmpty);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('el alta queda plegada tras su botón cuando ya hay datos', (tester) async {
    var open = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => CreateSection(
            label: 'Nueva meta',
            title: 'Nueva meta',
            open: open,
            onOpenChanged: (v) => setState(() => open = v),
            child: const Text('formulario'),
          ),
        ),
      ),
    );
    expect(find.text('formulario'), findsNothing);
    await tester.tap(find.text('Nueva meta'));
    await tester.pumpAndSettle();
    expect(find.text('formulario'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('formulario'), findsNothing);
  });

  testWidgets('sin datos el alta sale abierta y sin botón de cerrar', (tester) async {
    await tester.pumpWidget(
      _app(CreateSection(label: 'Nueva meta', title: 'Nueva meta', open: false, hasData: false, onOpenChanged: (_) {}, child: const Text('formulario'))),
    );
    expect(find.text('formulario'), findsOneWidget);
    expect(find.bySemanticsLabel('Cerrar'), findsNothing);
  });
}
