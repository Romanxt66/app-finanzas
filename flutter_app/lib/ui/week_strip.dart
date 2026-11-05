import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import 'glass.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';

/// Lunes de la semana de [d].
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// Tira de la semana (lun–dom) con flechas para cambiar de semana. Tocar un día lo elige; tocarlo otra
/// vez lo suelta. La píldora del día elegido se desliza de un día a otro.
class WeekStrip extends StatefulWidget {
  const WeekStrip({super.key, required this.selected, required this.onChanged, this.marked = const {}});

  /// Día elegido (yyyy-MM-dd) o null.
  final String? selected;
  final ValueChanged<String?> onChanged;

  /// Días con movimientos (yyyy-MM-dd): llevan un puntito.
  final Set<String> marked;

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> {
  late DateTime _week = weekStart(widget.selected != null ? parseIso(widget.selected!) : DateTime.now());

  @override
  void didUpdateWidget(WeekStrip old) {
    super.didUpdateWidget(old);
    final s = widget.selected;
    if (s != null && s != old.selected) _week = weekStart(parseIso(s));
  }

  void _shift(int weeks) {
    HapticFeedback.selectionClick();
    setState(() => _week = _week.add(Duration(days: 7 * weeks)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final today = todayISO();
    final days = [for (var i = 0; i < 7; i++) _week.add(Duration(days: i))];
    final selectedIndex = days.indexWhere((d) => isoDate(d) == widget.selected);
    final end = days.last;
    final range = _week.month == end.month
        ? '${_week.day}–${end.day} de ${DateFormat.MMMM('es').format(end)}'
        : '${_week.day} ${DateFormat.MMM('es').format(_week)} – ${end.day} ${DateFormat.MMM('es').format(end)}';
    Widget arrow(String label, int dir) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _shift(dir),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Transform.rotate(
              angle: dir < 0 ? 1.5708 : -1.5708,
              child: CrIcon('chevron', size: 18, color: c.inkMuted),
            ),
          ),
        ),
      ),
    );
    return Glass(
      padding: const EdgeInsets.fromLTRB(space2, space2, space2, space3),
      child: Column(
        children: [
          Row(
            children: [
              arrow('Semana anterior', -1),
              Expanded(
                child: Text(range, textAlign: TextAlign.center, style: CrText.mono(c.inkMuted, size: 11.5)),
              ),
              arrow('Semana siguiente', 1),
            ],
          ),
          LayoutBuilder(
            builder: (context, box) {
              final cell = box.maxWidth / 7;
              return SizedBox(
                height: 66,
                child: Stack(
                  children: [
                    // Píldora del día elegido
                    AnimatedPositioned(
                      duration: context.reduceMotion ? Duration.zero : CrMotion.base,
                      curve: crEase,
                      left: (selectedIndex < 0 ? 0 : selectedIndex) * cell + (cell - 44) / 2,
                      top: 18,
                      width: 44,
                      height: 44,
                      child: AnimatedOpacity(
                        duration: CrMotion.fast,
                        opacity: selectedIndex < 0 ? 0 : 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.neon,
                            boxShadow: [BoxShadow(color: c.neonGlow, blurRadius: 18)],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final (i, d) in days.indexed)
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final iso = isoDate(d);
                                final on = i == selectedIndex;
                                final isToday = iso == today;
                                return Semantics(
                                  button: true,
                                  selected: on,
                                  label: DateFormat("EEEE d 'de' MMMM", 'es').format(d),
                                  excludeSemantics: true,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onChanged(on ? null : iso);
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          DateFormat.E('es').format(d).substring(0, 1).toUpperCase(),
                                          style: CrText.mono(c.inkFaint, size: 11),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 44,
                                          child: Center(
                                            child: AnimatedDefaultTextStyle(
                                              duration: CrMotion.fast,
                                              style: CrText.display(on ? c.onNeon : c.ink, size: 17).copyWith(
                                                fontWeight: on || isToday ? FontWeight.w800 : FontWeight.w600,
                                                decoration: isToday && !on ? TextDecoration.underline : null,
                                                decorationColor: c.inkFaint,
                                              ),
                                              child: Text('${d.day}'),
                                            ),
                                          ),
                                        ),
                                        AnimatedOpacity(
                                          duration: CrMotion.fast,
                                          opacity: widget.marked.contains(iso) && !on ? 1 : 0,
                                          child: Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(shape: BoxShape.circle, color: c.inkMuted),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Encabezado de un día dentro de la lista («14 nov · viernes»).
class DayHeader extends StatelessWidget {
  const DayHeader(this.iso, {super.key, this.total});
  final String iso;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = parseIso(iso);
    final today = parseIso(todayISO());
    final diff = today.difference(d).inDays;
    final name = diff == 0
        ? 'hoy'
        : diff == 1
        ? 'ayer'
        : DateFormat.EEEE('es').format(d);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: space3, bottom: space1, left: space1, right: space1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(DateFormat("d MMM", 'es').format(d), style: CrText.heading(c.ink)),
            const SizedBox(width: space2),
            Text(name, style: CrText.mono(c.inkFaint, size: 11.5)),
            const Spacer(),
            if (total != null) Text(total!, style: CrText.mono(c.inkMuted, size: 11.5)),
          ],
        ),
      ),
    );
  }
}
