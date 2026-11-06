import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/legal.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppState> pump(WidgetTester tester, Widget child, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final state = AppState(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return state;
  }

  testWidgets('el aviso legal solo deja seguir tras marcar la casilla y guarda la versión', (tester) async {
    final state = await pump(tester, const Stack(children: [LegalConsent()]));
    expect(find.textContaining('Antes de'), findsOneWidget);
    await tester.tap(find.text('Aceptar y seguir'));
    await tester.pump();
    expect(state.legalAccepted, isNull);
    await tester.tap(find.text('Leí y acepto'));
    await tester.pump();
    await tester.tap(find.text('Aceptar y seguir'));
    await tester.pump();
    expect(state.legalAccepted, legalVersion);
  });

  testWidgets('si los textos cambian, el aviso lo dice', (tester) async {
    await pump(tester, const Stack(children: [LegalConsent()]), prefs: {'legal_accepted': '2020-01-01'});
    expect(find.textContaining('Actualizamos'), findsOneWidget);
  });

  testWidgets('los textos legales se leen completos y explican cómo borrar los datos', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, const LegalScreen(LegalDoc.privacy));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tus derechos'), findsOneWidget);
    expect(find.textContaining('Eliminar cuenta'), findsWidgets);
    expect(find.textContaining('Si entras con Google'), findsOneWidget);
    expect(find.textContaining(legalVersion), findsOneWidget);
  });
}
