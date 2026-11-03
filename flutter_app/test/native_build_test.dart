// La app entera compila fuera del navegador (VM de Dart, como en Android): si algún archivo importara
// `package:web` o `dart:js_interop` sin importación condicional, este test ni siquiera cargaría.
import 'package:alvea_app/core/biometric.dart';
import 'package:alvea_app/main.dart' as app;
import 'package:alvea_app/ui/dialogs.dart';
import 'package:alvea_app/ui/online.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la app y sus variantes nativas compilan sin APIs del navegador', () async {
    expect(app.main, isNotNull);
    // Fuera del navegador se da por conectada…
    expect(Online().value, isTrue);
    // …y en el VM de pruebas (no Android) no hay huella disponible
    expect(await biometricAvailable(), isFalse);
  });

  testWidgets('con el teclado abierto, los diálogos quedan por encima de él', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320); // teclado del teléfono
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCrDialog<void>(context, title: 'Crear PIN', builder: (_) => const SizedBox(height: 300)),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump(const Duration(milliseconds: 400));
    final dialogBottom = tester.getBottomLeft(find.text('Crear PIN')).dy + 300;
    expect(dialogBottom, lessThanOrEqualTo(844 - 320));
  });
}
