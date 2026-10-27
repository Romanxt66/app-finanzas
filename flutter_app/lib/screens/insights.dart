import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../ui/glass.dart';
import '../ui/mood_face.dart';
import '../ui/motion.dart';
import '../ui/query.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

// ─── Ánimo del gasto ────────────────────────────────────────────────────────────────────────────

/// Ánimos que se pueden marcar al registrar un gasto (claves de la API).
const spendingMoods = <String, ({String label, FaceExpression face})>{
  'happy': (label: 'Feliz', face: FaceExpression(color: Color(0xFFFACC15), smile: 0.85, eyeHappy: 0.9, blush: 0.6)),
  'calm': (label: 'Tranquilo', face: FaceExpression(color: Color(0xFF86EFAC), smile: 0.35, lid: 0.25)),
  'stressed': (label: 'Estresado', face: FaceExpression(color: Color(0xFFFB923C), smile: -0.45, brow: 1, browShow: 1, sweat: 0.9)),
  'sad': (label: 'Triste', face: FaceExpression(color: Color(0xFF93C5FD), smile: -0.8, brow: -1, browShow: 1, tear: 1)),
  'bored': (label: 'Aburrido', face: FaceExpression(color: Color(0xFFC4B5FD), smile: -0.05, lid: 0.75)),
};

const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábados', 'domingos'];

/// Frase del ánimo que más dinero se lleva («Cuando estás estresado gastas un 29 % más por compra…»).
String? moodHighlightText(MoodReport r) {
  final h = r.highlight;
  if (h == null) return null;
  final label = spendingMoods[h.mood]?.label.toLowerCase() ?? h.mood;
  final day = _weekdays[(h.weekday - 1).clamp(0, 6)];
  if (h.changePct.abs() < 5) return 'Cuando estás $label gastas lo de siempre por compra. Lo marcas más los $day.';
  final dir = h.changePct > 0 ? 'más' : 'menos';
  return 'Cuando estás $label gastas un ${formatPercent(h.changePct.abs())} % $dir por compra, sobre todo los $day.';
}

/// Selector de ánimo para el formulario de gasto: cinco caritas, se pulsa otra vez para quitarlo.
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('¿Cómo te sientes con este gasto? (opcional)', style: CrText.label(c.inkMuted)),
        const SizedBox(height: space2),
        Wrap(
          spacing: space2,
          runSpacing: space2,
          children: [
            for (final e in spendingMoods.entries)
              _MoodOption(
                label: e.value.label,
                face: e.value.face,
                selected: value == e.key,
                onTap: () => onChanged(value == e.key ? null : e.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _MoodOption extends StatelessWidget {
  const _MoodOption({required this.label, required this.face, required this.selected, required this.onTap});
  final String label;
  final FaceExpression face;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: crEase,
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radiusPill),
              color: selected ? face.color.withValues(alpha: 0.16) : c.panel.withValues(alpha: 0.5),
              border: Border.all(color: selected ? face.color : c.glassBorder, width: selected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: crPopEase,
                  child: MoodFace(expression: face, size: 30, lively: selected),
                ),
                const SizedBox(width: 6),
                Text(label, style: CrText.body(selected ? c.ink : c.inkMuted).copyWith(fontSize: 13.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resumen del ánimo con el que gastas (últimos 90 días).
class SpendingMoodCard extends StatelessWidget {
  const SpendingMoodCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Query<MoodReport>(
      load: () => context.app.data.spendingMood(),
      builder: (context, q) {
        final r = q.data;
        if (q.loading && r == null) return const Skeleton(lines: 1, height: 160);
        if (r == null) return ErrorText(q.error);
        return CrCard(
          title: 'Ánimo del gasto',
          meta: '90 días',
          child: r.tagged == 0
              ? Row(
                  children: [
                    MoodFace(expression: spendingMoods['calm']!.face, size: 44),
                    const SizedBox(width: space3),
                    Expanded(
                      child: Text(
                        'Al registrar un gasto, elige cómo te sientes. Con unos cuantos, verás en qué ánimo gastas más.',
                        style: CrText.body(c.inkMuted),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (moodHighlightText(r) case final text?) ...[
                      Row(
                        children: [
                          MoodFace(expression: spendingMoods[r.highlight!.mood]!.face, size: 48),
                          const SizedBox(width: space3),
                          Expanded(child: Text(text, style: CrText.body(c.ink))),
                        ],
                      ),
                      const SizedBox(height: space4),
                    ],
                    for (final m in r.byMood) ...[
                      Row(
                        children: [
                          MoodFace(expression: spendingMoods[m.mood]?.face ?? spendingMoods['calm']!.face, size: 26, lively: false),
                          const SizedBox(width: space2),
                          SizedBox(width: 84, child: Text(spendingMoods[m.mood]?.label ?? m.mood, style: CrText.body(c.ink))),
                          Expanded(
                            child: GrowBar(
                              ratio: m.sharePct / 100,
                              color: spendingMoods[m.mood]?.face.color ?? c.brand,
                              height: 6,
                              glow: true,
                            ),
                          ),
                          const SizedBox(width: space3),
                          Text(formatMoney(m.total, r.currency), style: CrText.amountSm(c.ink)),
                        ],
                      ),
                      const SizedBox(height: space2),
                    ],
                    Text(
                      '${r.tagged} de ${r.expenses} gastos con ánimo · media por compra según cómo te sentías',
                      style: CrText.mono(c.inkFaint, size: 11.5),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ─── Inflación personal ─────────────────────────────────────────────────────────────────────────

/// Cuánto se encareció lo que compras de verdad, frente a hace un año o seis meses.
class PersonalInflationCard extends StatelessWidget {
  const PersonalInflationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Query<PersonalInflation>(
      load: () => context.app.data.inflation(),
      builder: (context, q) {
        final r = q.data;
        if (q.loading && r == null) return const Skeleton(lines: 1, height: 180);
        if (r == null) return ErrorText(q.error);
        final index = r.indexPct;
        if (index == null) {
          return const CrCard(
            title: 'Tu inflación personal',
            child: CrEmpty('Cuando tengas gastos en los mismos comercios hace unos meses y ahora, verás cuánto se encareció tu vida.'),
          );
        }
        final up = index > 0.05;
        final down = index < -0.05;
        final color = up ? c.negative : (down ? c.positive : c.ink);
        final since = r.comparison == 'year' ? 'hace un año' : 'hace seis meses';
        return CrCard(
          title: 'Tu inflación personal',
          meta: 'vs $since',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: space3,
                runSpacing: space2,
                children: [
                  CountUp(
                    value: index,
                    builder: (context, v) => Text(
                      '${v > 0 ? '+' : ''}${formatPercent(double.parse(v.toStringAsFixed(1)))} %',
                      style: CrText.display(color, size: 48),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      up ? 'tu vida está más cara' : (down ? 'tu vida está más barata' : 'tus precios no se movieron'),
                      style: CrText.serif(c.inkMuted, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: space2),
              Text(
                'Precio medio por compra en los mismos ${r.matched} comercios, ponderado por lo que gastas en cada uno '
                '(cubre el ${formatPercent(r.coveragePct.roundToDouble())} % de tu gasto reciente).',
                style: CrText.caption(c.inkFaint),
              ),
              if (r.categories.length > 1) ...[
                const SizedBox(height: space4),
                Wrap(
                  spacing: space2,
                  runSpacing: space2,
                  children: [
                    for (final cat in r.categories.take(6))
                      CrBadge(
                        '${cat.category ?? 'Sin categoría'} ${cat.changePct > 0 ? '+' : ''}${formatPercent(cat.changePct)} %',
                        tone: cat.changePct > 0.05 ? Tone.negative : (cat.changePct < -0.05 ? Tone.positive : Tone.neutral),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: space4),
              for (final (i, item) in r.items.take(5).indexed)
                FadeIn(
                  delay: Duration(milliseconds: 40 * i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: space2),
                    decoration: BoxDecoration(
                      border: i == 0 ? null : Border(top: BorderSide(color: c.hairline)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.merchant, style: CrText.body(c.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                '${formatMoney(item.basePrice, r.currency)} → ${formatMoney(item.currentPrice, r.currency)} por compra',
                                style: CrText.mono(c.inkFaint, size: 11.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: space3),
                        Delta(item.changePct, invert: true),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Estado de ánimo financiero ─────────────────────────────────────────────────────────────────

/// Cómo está «Alvi», la carita del resumen, según la salud del mes.
class FinanceMood {
  const FinanceMood(this.level, this.score, this.reasons);

  /// 0 agobiada … 4 radiante.
  final int level;
  final int score;
  final List<String> reasons;

  static const titles = ['Alvi está agobiada', 'Alvi está preocupada', 'Alvi está tranquila', 'Alvi está contenta', 'Alvi está radiante'];
  static const messages = [
    'Tu dinero necesita un respiro: este mes sale más de lo que entra.',
    'Ojo, el mes se está apretando. Un par de ajustes y vuelve la calma.',
    'Todo en orden, sin sobresaltos. Sigue así.',
    'Vas muy bien este mes. ¡Bien hecho!',
    '¡Tus finanzas brillan! Ahorras y vas por debajo de tus límites.',
  ];
  static const faces = [
    FaceExpression(color: Color(0xFFF87171), smile: -1, mouthOpen: 0.3, brow: -1, browShow: 1, tear: 0.9, sweat: 0.6),
    FaceExpression(color: Color(0xFFFB923C), smile: -0.4, brow: -1, browShow: 1, sweat: 1),
    FaceExpression(color: Color(0xFFFACC15), smile: 0.25, lid: 0.15),
    FaceExpression(color: Color(0xFFC084FC), smile: 0.75, mouthOpen: 0.15, eyeHappy: 0.6, blush: 0.5),
    FaceExpression(color: Color(0xFFF472D0), smile: 1, mouthOpen: 0.75, eyeHappy: 1, blush: 0.8, sparkle: 1),
  ];

  String get title => titles[level];
  String get message => messages[level];
  FaceExpression get face => faces[level];
}

/// Calcula el ánimo del mes a partir del ahorro, el ritmo diario, los presupuestos y el saldo.
/// Cada parte suma puntos (máx. 100); sin datos, una parte cuenta como neutra.
FinanceMood financeMood({
  required double income,
  required double expense,
  required double balance,
  String? allowanceStatus,
  List<Budget> budgets = const [],
}) {
  var score = 0;
  final reasons = <String>[];

  if (income > 0) {
    final rate = (income - expense) / income * 100;
    if (rate >= 20) {
      score += 35;
    } else if (rate >= 10) {
      score += 25;
    } else if (rate >= 0) {
      score += 12;
    }
    reasons.add(rate >= 0 ? 'ahorras el ${rate.round()} %' : 'gastas ${rate.abs().round()} % más de lo que entra');
  } else {
    score += expense > 0 ? 6 : 15;
    if (expense > 0) reasons.add('sin ingresos este mes');
  }

  switch (allowanceStatus) {
    case 'ok':
      score += 30;
      reasons.add('vas dentro de tu ritmo');
    case 'tight':
      score += 12;
      reasons.add('hoy te pasaste del día');
    case 'over':
      reasons.add('sin margen para el resto del mes');
    default:
      score += 15;
  }

  final active = budgets.where((b) => b.amount > 0).toList();
  if (active.isEmpty) {
    score += 12;
  } else {
    final over = active.where((b) => b.spent > b.amount).length;
    score += (20 * (1 - over / active.length)).round();
    reasons.add(over == 0 ? 'ningún presupuesto excedido' : '$over presupuesto${over == 1 ? '' : 's'} excedido${over == 1 ? '' : 's'}');
  }

  if (balance > 0) {
    score += 15;
  } else if (balance < 0) {
    reasons.add('saldo en negativo');
  }

  final level = score >= 80
      ? 4
      : score >= 60
      ? 3
      : score >= 40
      ? 2
      : score >= 20
      ? 1
      : 0;
  return FinanceMood(level, score, reasons);
}

/// Tarjeta de la vista principal con la carita que refleja la salud del mes.
class FinanceMoodCard extends StatefulWidget {
  const FinanceMoodCard({super.key, required this.month, required this.income, required this.expense, required this.balance});
  final String month;
  final double income, expense, balance;

  @override
  State<FinanceMoodCard> createState() => _FinanceMoodCardState();
}

class _FinanceMoodCardState extends State<FinanceMoodCard> {
  final _face = GlobalKey<MoodFaceState>();
  int _tip = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    return Query<DailyAllowance?>(
      load: () => app.data.allowance(),
      builder: (context, aq) => Query<List<Budget>>(
        deps: widget.month,
        load: () => app.data.budgets(widget.month),
        builder: (context, bq) {
          final mood = financeMood(
            income: widget.income,
            expense: widget.expense,
            balance: widget.balance,
            allowanceStatus: aq.data?.status,
            budgets: bq.data ?? const [],
          );
          final wide = context.isWide;
          final faceSize = wide ? 132.0 : 104.0;
          final tip = mood.reasons.isEmpty ? null : mood.reasons[_tip % mood.reasons.length];
          final face = Semantics(
            button: true,
            label: '${mood.title}. Toca para ver por qué.',
            child: GestureDetector(
              onTap: () {
                _face.currentState?.boing();
                setState(() => _tip++);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: MoodFace(key: _face, expression: mood.face, size: faceSize),
              ),
            ),
          );
          final text = Column(
            crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('tu ánimo financiero', style: CrText.overline(c.inkFaint)),
              const SizedBox(height: space2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  mood.title,
                  key: ValueKey(mood.level),
                  style: CrText.display(c.ink, size: wide ? 32 : 26),
                  textAlign: wide ? TextAlign.start : TextAlign.center,
                ),
              ),
              const SizedBox(height: space1),
              Text(mood.message, style: CrText.body(c.inkMuted), textAlign: wide ? TextAlign.start : TextAlign.center),
              const SizedBox(height: space3),
              Wrap(
                spacing: space2,
                runSpacing: space2,
                alignment: wide ? WrapAlignment.start : WrapAlignment.center,
                children: [
                  for (final r in mood.reasons)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radiusPill),
                        color: r == tip ? mood.face.color.withValues(alpha: 0.18) : c.panel.withValues(alpha: 0.5),
                        border: Border.all(color: r == tip ? mood.face.color : c.glassBorder),
                      ),
                      child: Text(r, style: CrText.mono(c.ink, size: 11.5)),
                    ),
                ],
              ),
            ],
          );
          return Glass(
            strong: true,
            padding: const EdgeInsets.all(space5),
            borderColor: mood.face.color.withValues(alpha: 0.35),
            child: wide
                ? Row(
                    children: [
                      face,
                      const SizedBox(width: space5),
                      Expanded(child: text),
                    ],
                  )
                : Column(
                    children: [
                      face,
                      const SizedBox(height: space3),
                      text,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

// ─── Acceso a la sala de espera ─────────────────────────────────────────────────────────────────

/// Aviso en el resumen: compras en espera, listas para decidir y lo que no gastaste.
class WaitingTeaser extends StatelessWidget {
  const WaitingTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Query<WaitingRoom>(
      load: () => context.app.data.waitingRoom(),
      builder: (context, q) {
        final r = q.data;
        if (r == null) return const SizedBox.shrink();
        final saved = r.notSpent.map((t) => formatMoney(t.total, t.currency)).join(' · ');
        final line = r.ready > 0
            ? '${r.ready} compra${r.ready == 1 ? '' : 's'} lista${r.ready == 1 ? '' : 's'} para decidir'
            : r.waiting > 0
            ? '${r.waiting} compra${r.waiting == 1 ? '' : 's'} esperando'
            : '¿Te tienta algo? Déjalo 72 horas en espera antes de comprarlo.';
        return CrCard(
          title: 'Sala de espera',
          meta: saved.isEmpty ? null : 'no gastaste $saved',
          child: Row(
            children: [
              CrChip('target', tone: r.ready > 0 ? Tone.amber : Tone.brand),
              const SizedBox(width: space3),
              Expanded(child: Text(line, style: CrText.body(c.ink))),
              const SizedBox(width: space3),
              CrLink(r.waiting > 0 ? 'Ver' : 'Probar', onTap: () => context.go('/waiting')),
            ],
          ),
        );
      },
    );
  }
}
