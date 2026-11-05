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
    expect(backdropFilter(accentById('frio'), GlowLevel.normal), isNotNull);
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

  test('la app es monocroma y el tono solo tiñe levemente los grises', () {
    for (final base in [crPaletteDark, crPaletteLight]) {
      for (final color in [base.brand, base.brandFill, base.ink, base.positive, base.negative, base.chart2]) {
        expect(HSLColor.fromColor(color).saturation, lessThan(0.01));
      }
    }
    final p = tintPalette(crPaletteDark, accentById('frio'), GlowLevel.normal);
    expect(HSLColor.fromColor(p.inkMuted).hue, closeTo(214, 2));
    expect(HSLColor.fromColor(p.inkMuted).saturation, lessThan(0.15));
    final soft = tintPalette(crPaletteDark, fuchsiaAccent, GlowLevel.soft);
    expect(soft.bgGlowBrand.a, lessThan(crPaletteDark.bgGlowBrand.a));
  });

  testWidgets('elegir un tono y la luz del fondo se guarda y se puede deshacer', (tester) async {
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
    expect(find.text('Volver al estilo original'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Cálido'));
    await tester.tap(find.text('Intensa'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.accent.id, 'calido');
    expect(state.glow, GlowLevel.vivid);
    expect(prefs.getString('accent'), 'calido');
    expect(AppState(prefs).accent.id, 'calido');

    await tester.ensureVisible(find.text('Volver al estilo original'));
    await tester.tap(find.text('Volver al estilo original'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.accent, fuchsiaAccent);
    expect(state.glow, GlowLevel.normal);
  });
}
