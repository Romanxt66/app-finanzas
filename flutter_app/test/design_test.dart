import 'package:alvea_app/ui/glass.dart';
import 'package:alvea_app/ui/intro.dart';
import 'package:alvea_app/ui/logo.dart';
import 'package:alvea_app/ui/motion.dart';
import 'package:alvea_app/ui/page.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:alvea_app/ui/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.dark}) => MaterialApp(
  theme: buildTheme(brightness),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('entrada de la app', introTests);

  group('rendimiento', () {
    testWidgets('las tarjetas de vidrio no desenfocan el fondo en cada fotograma', (tester) async {
      await tester.pumpWidget(_app(const Glass(child: Text('panel'))));
      expect(find.text('panel'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('el fondo es estático: no pide fotogramas nuevos', (tester) async {
      await tester.pumpWidget(_app(const SizedBox(width: 1200, height: 800, child: CrBackdrop(child: SizedBox()))));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('los módulos fuera de pantalla aparecen al desplazar', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 600,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 900),
                  Rise(
                    child: Container(key: const ValueKey('abajo'), height: 100, color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double opacity() => tester
          .widget<Opacity>(
            find.ancestor(of: find.byKey(const ValueKey('abajo'), skipOffstage: false), matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(opacity(), 0, reason: 'sigue oculto mientras no se ve');
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
    });

    testWidgets('siguen apareciendo si la zona desplazable cambia de posición (rueda del ratón)', (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget page(ScrollBehavior behavior) => _app(
        ScrollConfiguration(
          behavior: behavior,
          child: PageScaffold(
            children: [for (var i = 0; i < 6; i++) Container(key: ValueKey(i), height: 300, color: Colors.red)],
          ),
        ),
      );
      await tester.pumpWidget(page(const _Behavior(BouncingScrollPhysics())));
      await tester.pumpAndSettle();
      double opacity(int i) => tester
          .widget<Opacity>(find.ancestor(of: find.byKey(ValueKey(i), skipOffstage: false), matching: find.byType(Opacity)).first)
          .opacity;
      expect(opacity(4), 0);
      // Un cambio de configuración crea una posición de desplazamiento nueva
      await tester.pumpWidget(page(const _Behavior(ClampingScrollPhysics())));
      await tester.pump();
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(500, 300)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 800)));
      await tester.pumpAndSettle();
      expect(opacity(4), 1);
    });

    testWidgets('el logo de Alvea se anuncia a lectores de pantalla', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const AlveaLogo(size: 48)));
      expect(find.bySemanticsLabel('Alvea'), findsOneWidget);
      handle.dispose();
    });
  });

  group('parseAccent', () {
    test('separa la palabra destacada entre asteriscos', () {
      expect(parseAccent('Tu dinero, *claro*.'), [('Tu dinero, ', false), ('claro', true), ('.', false)]);
    });

    test('admite varias palabras dentro del acento y texto sin acento', () {
      expect(parseAccent('Cobros que *no ves venir*.'), [('Cobros que ', false), ('no ves venir', true), ('.', false)]);
      expect(parseAccent('Resumen.'), [('Resumen.', false)]);
    });

    test('un asterisco suelto se deja tal cual', () {
      expect(parseAccent('5 * 3'), [('5 * 3', false)]);
    });

    test('plainAccent quita las marcas para lectores de pantalla', () {
      expect(plainAccent('Gasta con *intención*.'), 'Gasta con intención.');
    });
  });

  group('encabezados', () {
    testWidgets('CrHeadline se anuncia como encabezado con el texto limpio', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const CrHeadline('Tu dinero, *claro*.')));
      expect(find.bySemanticsLabel('Tu dinero, claro.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('PageHead muestra la etiqueta de sección y el titular', (tester) async {
      await tester.pumpWidget(_app(const PageHead('Metas', headline: 'Ahorra para lo que *importa*.')));
      await tester.pumpAndSettle();
      expect(find.text('metas'), findsOneWidget);
      expect(find.textContaining('Ahorra para lo que', findRichText: true), findsOneWidget);
    });

    testWidgets('sin titular propio usa el título de la pantalla', (tester) async {
      await tester.pumpWidget(_app(const PageHead('Perfil')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Perfil.', findRichText: true), findsOneWidget);
    });
  });

  group('acentos neón', () {
    test('el texto sobre neón contrasta en ambos temas', () {
      for (final p in [crPaletteDark, crPaletteLight]) {
        final ratio = _contrast(p.neon, p.onNeon);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: 'contraste ${ratio.toStringAsFixed(2)}');
      }
    });

    testWidgets('CrTag y CrBadge de marca se pintan en los dos temas', (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(
          _app(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CrTag('en línea', pulse: true),
                CrBadge('lograda', tone: Tone.brand),
              ],
            ),
            brightness: b,
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('en línea'), findsOneWidget);
        expect(find.text('lograda'), findsOneWidget);
      }
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _introScale(WidgetTester tester) {
  final t = tester.widget<Transform>(find.descendant(of: find.byType(BrandIntro), matching: find.byType(Transform)).first);
  return t.transform.getMaxScaleOnAxis();
}

void introTests() {
  testWidgets('la entrada del logo crece hasta cubrir la pantalla y desaparece', (tester) async {
    BrandIntro.reset();
    await tester.pumpWidget(_app(const SizedBox(width: 800, height: 600, child: Stack(children: [BrandIntro()]))));
    final start = _introScale(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final mid = _introScale(tester);
    expect(mid, greaterThan(start * 3), reason: 'escala $start → $mid');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(find.descendant(of: find.byType(BrandIntro), matching: find.byType(Transform)), findsNothing);
  });

  testWidgets('se ve una sola vez por sesión', (tester) async {
    BrandIntro.reset();
    await tester.pumpWidget(_app(const Stack(children: [BrandIntro()])));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(const Stack(children: [BrandIntro(key: ValueKey(2))])));
    expect(find.descendant(of: find.byType(BrandIntro), matching: find.byType(Transform)), findsNothing);
  });
}

class _Behavior extends MaterialScrollBehavior {
  const _Behavior(this.physics);
  final ScrollPhysics physics;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;

  @override
  bool shouldNotify(_Behavior oldDelegate) => oldDelegate.physics.runtimeType != physics.runtimeType;
}
