import 'package:alvea_app/core/models.dart';
import 'package:alvea_app/screens/insights.dart';
import 'package:alvea_app/screens/waiting_room.dart';
import 'package:alvea_app/ui/mood_face.dart';
import 'package:alvea_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildTheme(Brightness.dark),
  home: Scaffold(body: Center(child: child)),
);

Budget _budget(double amount, double spent) => Budget.fromJson({'id': 'b', 'category_id': 'c', 'amount': '$amount', 'spent': '$spent'});

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('ánimo financiero', () {
    test('mes sano: radiante', () {
      final m = financeMood(income: 2000, expense: 1200, balance: 3000, allowanceStatus: 'ok', budgets: [_budget(300, 120)]);
      expect(m.level, 4);
      expect(m.reasons, containsAll(['ahorras el 40 %', 'vas dentro de tu ritmo', 'ningún presupuesto excedido']));
    });

    test('gastar más de lo que entra y pasarse de todo: agobiada', () {
      final m = financeMood(income: 1000, expense: 1500, balance: -50, allowanceStatus: 'over', budgets: [_budget(100, 300)]);
      expect(m.level, 0);
      expect(m.reasons, contains('gastas 50 % más de lo que entra'));
      expect(m.reasons, contains('1 presupuesto excedido'));
      expect(m.reasons, contains('saldo en negativo'));
    });

    test('sin datos queda tranquila, no alarmada', () {
      final m = financeMood(income: 0, expense: 0, balance: 0);
      expect(m.level, 2);
      expect(m.reasons, isEmpty);
    });

    test('cada nivel tiene título, mensaje y carita', () {
      for (var level = 0; level <= 4; level++) {
        final m = FinanceMood(level, 0, const []);
        expect(m.title, startsWith('Alvi está'));
        expect(m.message, isNotEmpty);
        expect(m.says, isNotEmpty);
        expect(m.face, isA<FaceExpression>());
      }
    });
  });

  group('ánimo del gasto', () {
    MoodReport report(double change) => MoodReport.fromJson({
      'currency': 'EUR',
      'expenses': 6,
      'tagged': 4,
      'by_mood': [],
      'highlight': {'mood': 'stressed', 'average': '30.00', 'baseline': '23.33', 'change_pct': '$change', 'top_weekday': 5},
    });

    test('frase del ánimo que más gasta', () {
      expect(moodHighlightText(report(28.6)), 'Cuando estás estresado gastas un 28,6 % más por compra, sobre todo los viernes.');
      expect(moodHighlightText(report(-12)), contains('12 % menos'));
      expect(moodHighlightText(report(2)), contains('lo de siempre'));
    });

    testWidgets('el selector marca y desmarca un ánimo', (tester) async {
      String? value;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => MoodPicker(value: value, onChanged: (v) => set(() => value = v)),
          ),
        ),
      );
      await tester.tap(find.text('Estresado'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(value, 'stressed');
      await tester.tap(find.text('Estresado'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(value, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('carita', () {
    testWidgets('pasa de una expresión a otra suavemente y se anuncia', (tester) async {
      final handle = tester.ensureSemantics();
      Widget face(int level) => _app(MoodFace(expression: FinanceMood.faces[level], size: 80, semanticLabel: 'Alvi'));
      await tester.pumpWidget(face(4));
      expect(find.bySemanticsLabel('Alvi'), findsOneWidget);
      await tester.pumpWidget(face(0));
      await tester.pump(const Duration(milliseconds: 200));
      final mid =
          tester.widget<CustomPaint>(find.descendant(of: find.byType(MoodFace), matching: find.byType(CustomPaint))).painter!
              as FacePainter;
      // A mitad de camino la sonrisa todavía no es la tristeza final
      expect(mid.f.smile, inExclusiveRange(-1.0, 1.0));
      await tester.pump(const Duration(milliseconds: 700));
      final end =
          tester.widget<CustomPaint>(find.descendant(of: find.byType(MoodFace), matching: find.byType(CustomPaint))).painter!
              as FacePainter;
      expect(end.f.smile, -1);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    test('lerp mezcla color y rasgos', () {
      const a = FaceExpression(color: Colors.black, smile: -1);
      const b = FaceExpression(color: Colors.white, smile: 1, sparkle: 1);
      final m = FaceExpression.lerp(a, b, 0.5);
      expect(m.smile, 0);
      expect(m.sparkle, 0.5);
    });
  });

  group('sala de espera', () {
    test('cuenta atrás legible', () {
      expect(timeLeft(const Duration(days: 2, hours: 5)), '2 d 5 h');
      expect(timeLeft(const Duration(hours: 3)), '3 h');
      expect(timeLeft(const Duration(minutes: 40)), '40 min');
      expect(timeLeft(const Duration(seconds: 20)), 'menos de un minuto');
    });

    test('modelo de la sala', () {
      final room = WaitingRoom.fromJson({
        'items': [
          {
            'id': '1',
            'created_at': '2026-10-27T10:00:00Z',
            'name': 'Auriculares',
            'amount': '89.90',
            'currency': 'EUR',
            'wait_hours': 72,
            'ready_at': '2026-10-30T10:00:00Z',
            'status': 'waiting',
            'decided_at': null,
            'ready': false,
          },
        ],
        'waiting': 1,
        'ready': 0,
        'skipped': 0,
        'bought': 0,
        'not_spent': [
          {'currency': 'EUR', 'total': '60.00'},
        ],
      });
      expect(room.items.single.amount, 89.9);
      expect(room.items.single.readyAt.difference(room.items.single.createdAt).inHours, 72);
      expect(room.notSpent.single.total, 60);
    });
  });
}
