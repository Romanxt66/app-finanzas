import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'glass.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';

/// Iniciales para el avatar de una tarjeta («Cuenta principal» → «CP»).
String initials(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '·';
  if (words.length == 1) return words.first.characters.take(2).toString().toUpperCase();
  return (words[0].characters.first + words[1].characters.first).toUpperCase();
}

/// Curva suave que pasa por todos los puntos sin pasarse de ellos (interpolación cúbica monótona,
/// Fritsch–Carlson): no inventa valles bajo cero ni picos que no existen.
Path monotonePath(List<Offset> p) {
  final path = Path()..moveTo(p.first.dx, p.first.dy);
  if (p.length < 2) return path;
  final n = p.length;
  final d = [for (var i = 0; i < n - 1; i++) (p[i + 1].dy - p[i].dy) / (p[i + 1].dx - p[i].dx)];
  final m = List<double>.filled(n, 0);
  m[0] = d.first;
  m[n - 1] = d.last;
  for (var i = 1; i < n - 1; i++) {
    m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
  }
  for (var i = 0; i < n - 1; i++) {
    if (d[i] == 0) {
      m[i] = 0;
      m[i + 1] = 0;
      continue;
    }
    final a = m[i] / d[i], b = m[i + 1] / d[i];
    final h = a * a + b * b;
    if (h > 9) {
      final t = 3 / math.sqrt(h);
      m[i] = t * a * d[i];
      m[i + 1] = t * b * d[i];
    }
  }
  for (var i = 0; i < n - 1; i++) {
    final h = (p[i + 1].dx - p[i].dx) / 3;
    path.cubicTo(p[i].dx + h, p[i].dy + m[i] * h, p[i + 1].dx - h, p[i + 1].dy - m[i + 1] * h, p[i + 1].dx, p[i + 1].dy);
  }
  return path;
}

/// Color de cada tipo de movimiento (`income`, `expense`, `transfer`) en tarjetas y columnas.
Color txColor(CrPalette c, String type) => switch (type) {
  'income' => c.positive,
  'expense' => c.neon,
  _ => c.chart4,
};

/// Píldora pequeña del pie de una tarjeta (categoría, fecha, estado…).
class DealChip {
  const DealChip(this.label, {this.icon, this.color, this.dot = false});
  final String label;
  final String? icon;
  final Color? color;

  /// Punto de color delante del texto (como «• 1 open»).
  final bool dot;
}

/// Tarjeta translúcida estilo «pipeline»: avatar con iniciales, título y subtítulo arriba; una
/// etiqueta pequeña y la cifra grande en el centro (con mini gráfica opcional); una línea fina de
/// progreso y chips abajo. Las acciones van discretas arriba a la derecha.
class DealCard extends StatelessWidget {
  const DealCard({
    super.key,
    required this.title,
    this.subtitle,
    this.avatar,
    this.accent,
    this.eyebrow,
    this.value,
    this.valueColor,
    this.spark,
    this.progress,
    this.chips = const [],
    this.trailing,
    this.actions = const [],
    this.footer,
    this.dimmed = false,
    this.semanticLabel,
  });
  final String title;
  final String? subtitle;

  /// Texto del avatar (iniciales); null = sin avatar.
  final String? avatar;
  final Color? accent;
  final String? eyebrow;
  final String? value;
  final Color? valueColor;
  final List<double>? spark;
  final double? progress;
  final List<DealChip> chips;
  final String? trailing;
  final List<Widget> actions;
  final Widget? footer;
  final bool dimmed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = accent ?? c.neon;
    final card = Glass(
      lift: true,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(space4, space4, space3, space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avatar != null) ...[DealAvatar(avatar!, color: color), const SizedBox(width: space3)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CrText.heading(c.ink).copyWith(fontSize: 14.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(subtitle!, style: CrText.mono(c.inkFaint, size: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (actions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ),
          if (value != null) ...[
            const SizedBox(height: space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null) Text(eyebrow!.toLowerCase(), style: CrText.mono(c.inkFaint, size: 11)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(value!, style: CrText.display(valueColor ?? c.ink, size: 24)),
                      ),
                    ],
                  ),
                ),
                if (spark != null && spark!.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: space2, bottom: 4),
                    child: SizedBox(
                      width: 84,
                      height: 30,
                      child: MiniSpark(data: spark!, color: color),
                    ),
                  ),
              ],
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: space3),
            GrowBar(ratio: progress!.clamp(0, 1), color: color, height: 3, glow: true),
          ],
          if (chips.isNotEmpty || trailing != null) ...[
            const SizedBox(height: space3),
            Row(
              children: [
                Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [for (final ch in chips) _ChipView(ch)])),
                if (trailing != null) Text(trailing!, style: CrText.mono(c.inkFaint, size: 11)),
              ],
            ),
          ],
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(top: space3),
              child: footer,
            ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      child: AnimatedOpacity(opacity: dimmed ? 0.55 : 1, duration: const Duration(milliseconds: 200), child: card),
    );
  }
}

class DealAvatar extends StatelessWidget {
  const DealAvatar(this.text, {super.key, required this.color, this.size = 34});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(color, c.bg, 0.55),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: CrText.mono(c.ink, size: size * 0.32, weight: FontWeight.w500),
      ),
    );
  }
}

class _ChipView extends StatelessWidget {
  const _ChipView(this.chip);
  final DealChip chip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = chip.color ?? c.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusPill),
        color: c.panel.withValues(alpha: 0.55),
        border: Border.all(color: c.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip.dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          if (chip.icon != null) ...[CrIcon(chip.icon!, size: 12, color: color), const SizedBox(width: 4)],
          Text(chip.label, style: CrText.mono(chip.dot ? c.ink : color, size: 10.5)),
        ],
      ),
    );
  }
}

/// Mini gráfica de línea para las tarjetas (con un leve sombreado debajo).
class MiniSpark extends StatelessWidget {
  const MiniSpark({super.key, required this.data, required this.color});
  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
    duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
    curve: crEase,
    builder: (context, v, _) => CustomPaint(painter: _MiniSparkPainter(data, color, v)),
  );
}

class _MiniSparkPainter extends CustomPainter {
  _MiniSparkPainter(this.data, this.color, this.progress);
  final List<double> data;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = data.reduce(math.min), hi = data.reduce(math.max);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final pts = [
      for (var i = 0; i < data.length; i++)
        Offset(size.width * i / (data.length - 1), size.height - 2 - (size.height - 4) * (data[i] - lo) / span),
    ];
    final path = monotonePath(pts);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [color.withValues(alpha: 0.25), color.withValues(alpha: 0)]),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniSparkPainter old) => old.progress != progress || old.color != color || old.data != data;
}

/// Resumen de cabecera (como «Trade & designers · $528k · 7 accounts»): icono de color, etiqueta,
/// cifra grande y una nota; con [progress], una línea fina debajo.
class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.note,
    this.progress,
    this.selected = false,
    this.onTap,
  });
  final String label, value;
  final String? icon;
  final Color? color;
  final String? note;
  final double? progress;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = color ?? c.neon;
    return Glass(
      lift: onTap != null,
      radius: 16,
      onTap: onTap,
      borderColor: selected ? tint.withValues(alpha: 0.7) : null,
      padding: const EdgeInsets.all(space4),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
              child: Center(child: CrIcon(icon!, size: 18, color: const Color(0xFF1A0420))),
            ),
            const SizedBox(width: space3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toLowerCase(), style: CrText.mono(c.inkFaint, size: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: CrText.display(c.ink, size: 22)),
                ),
                if (note != null) Text(note!, style: CrText.mono(c.inkFaint, size: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (progress != null) ...[
                  const SizedBox(height: space2),
                  GrowBar(ratio: progress!.clamp(0, 1), color: tint, height: 3, glow: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuadrícula adaptable de tarjetas del mismo ancho (mínimo [minWidth]).
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.minWidth = 250, this.maxColumns = 4});
  final List<Widget> children;
  final double minWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = ((box.maxWidth + space3) / (minWidth + space3)).floor().clamp(1, maxColumns);
      final width = (box.maxWidth - space3 * (cols - 1)) / cols;
      return Wrap(
        spacing: space3,
        runSpacing: space3,
        children: [
          for (var i = 0; i < children.length; i++)
            SizedBox(
              width: width,
              child: FadeIn(
                delay: Duration(milliseconds: 30 * math.min(i, 8)),
                child: children[i],
              ),
            ),
        ],
      );
    },
  );
}

/// Columna de tablero (como «● Negotiating 4 · $81.2k»): cabecera con punto, nombre, número y total.
class BoardColumn extends StatelessWidget {
  const BoardColumn({super.key, required this.title, required this.color, required this.count, this.total, required this.children});
  final String title;
  final Color color;
  final int count;
  final String? total;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(space2, 0, space2, space3),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: space2),
              Text(title, style: CrText.label(c.ink)),
              const SizedBox(width: space2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(radiusPill), color: c.panel.withValues(alpha: 0.6)),
                child: Text('$count', style: CrText.mono(c.inkMuted, size: 10.5)),
              ),
              const Spacer(),
              if (total != null) Text(total!, style: CrText.mono(c.inkMuted, size: 11)),
            ],
          ),
        ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: space3),
          FadeIn(
            delay: Duration(milliseconds: 30 * math.min(i, 8)),
            child: children[i],
          ),
        ],
      ],
    );
  }
}

/// Botón de icono discreto para las acciones de una tarjeta.
class CardAction extends StatelessWidget {
  const CardAction({super.key, required this.icon, required this.tooltip, required this.onPressed, this.danger = false});
  final String icon, tooltip;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: MouseRegion(
          cursor: onPressed == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: PressScale(
            enabled: onPressed != null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: CrIcon(icon, size: 15, color: danger ? c.negative : c.inkMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
