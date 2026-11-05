import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

/// Un trozo del anillo.
class DonutSlice {
  const DonutSlice(this.label, this.value, {this.note, this.trailing});
  final String label;
  final double value;
  final String? note;
  final String? trailing;
}

/// Grises de los trozos (de más claro a más oscuro en oscuro; al revés en claro): se distinguen por luz.
List<Color> donutShades(CrPalette c) => [c.neon, c.chart2, c.chart3, c.chart4, c.chart5, c.inkFaint];

/// Anillo con el total en el centro y la leyenda (punto, nombre, nota y cifra) al lado o debajo.
/// Se dibuja girando al entrar; sin animación si el sistema pide reducir movimiento.
class DonutCard extends StatelessWidget {
  const DonutCard({super.key, required this.slices, required this.centerLabel, required this.centerValue, this.title});
  final List<DonutSlice> slices;
  final String centerLabel;
  final Widget centerValue;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shades = donutShades(c);
    final total = slices.fold<double>(0, (t, s) => t + math.max(0, s.value));
    final ring = SizedBox.square(
      dimension: 196,
      child: Semantics(
        label: '$centerLabel. ${[for (final s in slices) '${s.label} ${total > 0 ? (s.value / total * 100).round() : 0} %'].join(', ')}',
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: crEase,
                builder: (context, t, _) => CustomPaint(
                  size: const Size.square(196),
                  painter: _DonutPainter(
                    values: [for (final s in slices) math.max(0, s.value)],
                    colors: [for (var i = 0; i < slices.length; i++) shades[i % shades.length]],
                    track: c.ink.withValues(alpha: 0.06),
                    progress: t,
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.panel,
                        borderRadius: BorderRadius.circular(radiusPill),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: Text(centerLabel, style: CrText.mono(c.inkMuted, size: 10.5)),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(fit: BoxFit.scaleDown, child: centerValue),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, s) in slices.indexed)
          FadeIn(
            delay: Duration(milliseconds: 60 + 40 * math.min(i, 8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: shades[i % shades.length],
                      border: Border.all(color: c.glassBorder),
                    ),
                  ),
                  const SizedBox(width: space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.label,
                          style: CrText.body(c.ink).copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (s.note != null) Text(s.note!, style: CrText.caption(c.inkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: space2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (s.trailing != null) Text(s.trailing!, style: CrText.amountSm(c.ink)),
                      Text('${total > 0 ? (math.max(0, s.value) / total * 100).round() : 0} %', style: CrText.mono(c.inkFaint, size: 10.5)),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    return Glass(
      padding: const EdgeInsets.all(space5),
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 560;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[SectionTitle(title!), const SizedBox(height: space3)],
              if (wide)
                Row(
                  children: [
                    ring,
                    const SizedBox(width: space6),
                    Expanded(child: legend),
                  ],
                )
              else ...[
                Center(child: ring),
                const SizedBox(height: space4),
                legend,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors, required this.track, required this.progress});
  final List<double> values;
  final List<Color> colors;
  final Color track;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 26.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    // Pequeño hueco entre trozos para que se lean como piezas distintas
    final gap = values.where((v) => v > 0).length > 1 ? 0.035 : 0.0;
    var start = -math.pi / 2;
    final sweepAll = math.pi * 2 * progress;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * sweepAll;
      if (sweep <= 0) continue;
      canvas.drawArc(
        arcRect,
        start + gap / 2,
        math.max(0.001, sweep - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.values != values || old.colors != colors;
}
