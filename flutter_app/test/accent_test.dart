import 'package:alvea_app/core/state.dart';
import 'package:alvea_app/screens/appearance.dart';
import 'package:alvea_app/ui/accent.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('los colores por defecto no cambian nada', () {
    expect(identical(tintPalette(crPaletteDark, fuchsiaAccent, GlowLevel.normal), crPaletteDark), isTrue);
    expect(backdropFilter(fuchsiaAccent, GlowLevel.normal), isNull);
    expect(backdropFilter(accentById('azul'), GlowLevel.normal), isNotNull);
    expect(accentById('no-existe'), fuchsiaAccent);
    expect(glowById('vivid'), GlowLevel.vivid);
  });

  test('todos los acentos mantienen el texto legible en los dos temas', () {
    for (final a in accentChoices) {
      for (final g in GlowLevel.values) {
        for (final base in [crPaletteDark, crPaletteLight]) {
          final p = tintPalette(base, a, g);
          final why = '${a.label} · ${g.label} · ${base == crPaletteDark ? 'oscuro' : 'claro'}';
          expect(contrastRatio(p.neon, p.onNeon), greaterThanOrEqualTo(4.5), reason: 'texto sobre neón · $why');
          expect(contrastRatio(p.brand, p.bg), greaterThanOrEqualTo(4.5), reason: 'texto de marca · $why');
          if (base == crPaletteLight) {
            expect(contrastRatio(p.brandFill, p.onBrand), greaterThanOrEqualTo(4.5), reason: 'relleno · $why');
          }
        }
      }
    }
  });

  test('el acento cambia el matiz del neón', () {
    final p = tintPalette(crPaletteDark, accentById('turquesa'), GlowLevel.normal);
    expect(HSLColor.fromColor(p.focus).hue, closeTo(178, 2));
    final soft = tintPalette(crPaletteDark, fuchsiaAccent, GlowLevel.soft);
    expect(soft.bgGlowBrand.a, lessThan(crPaletteDark.bgGlowBrand.a));
  });

  testWidgets('elegir un color y la luz del fondo se guarda y se puede deshacer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => MaterialApp(
            theme: buildTheme(Brightness.dark, accent: state.accent, glow: state.glow),
            home: const Scaffold(body: SingleChildScrollView(child: AppearanceCard())),
          ),
        ),
      ),
    );
    expect(find.text('Volver a los colores de Alvea'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Esmeralda'));
    await tester.tap(find.text('Intensa'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.accent.id, 'esmeralda');
    expect(state.glow, GlowLevel.vivid);
    expect(prefs.getString('accent'), 'esmeralda');
    expect(AppState(prefs).accent.id, 'esmeralda');

    await tester.ensureVisible(find.text('Volver a los colores de Alvea'));
    await tester.tap(find.text('Volver a los colores de Alvea'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.accent, fuchsiaAccent);
    expect(state.glow, GlowLevel.normal);
  });
}
