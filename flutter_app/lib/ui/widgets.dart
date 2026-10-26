import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import 'buttons.dart';
import 'glass.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';

/// Encabezado de pantalla: título a la izquierda y controles a la derecha (`.cr-page-head`).
class PageHead extends StatelessWidget {
  const PageHead(this.title, {super.key, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: space3,
      runSpacing: space3,
      children: [
        // Margen de 0,67em del h1 de la web
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13.4),
          child: Semantics(header: true, child: Text(title, style: CrText.title(c.ink))),
        ),
        ...actions,
      ],
    );
  }
}

/// Tarjeta de vidrio con título (`Card`).
class CrCard extends StatelessWidget {
  const CrCard({super.key, this.title, this.action, required this.child, this.flush = false});
  final String? title;
  final Widget? action;
  final Widget child;
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Glass(
      padding: flush ? EdgeInsets.zero : const EdgeInsets.all(space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || action != null)
            Padding(
              padding: flush ? const EdgeInsets.fromLTRB(space4, space4, space4, space3) : const EdgeInsets.only(bottom: space3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null)
                    Expanded(
                      child: Semantics(header: true, child: Text(title!, style: CrText.heading(c.ink))),
                    ),
                  ?action,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Título de sección fuera de tarjeta (`.cr-card-title` + h2).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: space3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(header: true, child: Text(title, style: CrText.heading(context.c.ink))),
        ?trailing,
      ],
    ),
  );
}

class CrEmpty extends StatelessWidget {
  const CrEmpty(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: space6, horizontal: space4),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w500,
          color: context.c.inkMuted,
        ),
      ),
    ),
  );
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.error, {super.key});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final msg = error is ApiError ? (error as ApiError).message : 'Error inesperado';
    return Padding(
      padding: const EdgeInsets.only(top: space1),
      child: Semantics(
        liveRegion: true,
        child: Text(
          msg,
          style: TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFallback,
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            color: context.c.negative,
          ),
        ),
      ),
    );
  }
}

enum Tone { neutral, positive, negative, warning, brand, amber }

class CrBadge extends StatelessWidget {
  const CrBadge(this.text, {super.key, this.tone = Tone.neutral, this.icon});
  final String text;
  final Tone tone;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border) = switch (tone) {
      Tone.positive => (c.positiveSoft, c.positive, Colors.transparent),
      Tone.negative => (c.negativeSoft, c.negative, Colors.transparent),
      Tone.warning => (c.amberSoft, c.amber, Colors.transparent),
      _ => (c.glassStrong, c.inkMuted, c.glassBorder),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[CrIcon(icon!, size: 12, color: fg), const SizedBox(width: space1)],
          Text(
            text,
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: fontFallback,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Variación porcentual con flecha y signo (no solo color).
class Delta extends StatelessWidget {
  const Delta(this.value, {super.key, this.invert = false});
  final double value;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    final good = invert ? !up : up;
    return CrBadge(
      '${up ? '+' : '−'}${formatPercent(value.abs())} %',
      tone: good ? Tone.positive : Tone.negative,
      icon: up ? 'up' : 'down',
    );
  }
}

/// Icono en chip (`.cr-chip`).
class CrChip extends StatelessWidget {
  const CrChip(this.icon, {super.key, this.tone = Tone.neutral});
  final String icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      Tone.brand => (c.brandSoft, c.brand),
      Tone.amber => (c.amberSoft, c.amber),
      Tone.negative => (c.negativeSoft, c.negative),
      _ => (c.glassStrong, c.ink),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radiusSm)),
      child: Center(child: CrIcon(icon, size: 20, color: fg)),
    );
  }
}

/// Cifra que cuenta hasta su valor.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({super.key, required this.value, this.currency, required this.style});
  final double value;
  final String? currency;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => CountUp(
    value: value,
    builder: (context, v) => Text(formatMoney(v, currency), style: style),
  );
}

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.data, required this.label});
  final List<double> data;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();
    return Semantics(
      label: label,
      image: true,
      child: SizedBox(width: 120, height: 40, child: CustomPaint(painter: _SparkPainter(data, context.c.brand))),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.data, this.color);
  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 3.0;
    final mn = data.reduce(math.min);
    final span = (data.reduce(math.max) - mn) == 0 ? 1.0 : data.reduce(math.max) - mn;
    final pts = [
      for (var i = 0; i < data.length; i++)
        Offset(pad + i * (size.width - pad * 2) / (data.length - 1), pad + (1 - (data[i] - mn) / span) * (size.height - pad * 2)),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.drawCircle(pts.last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.data != data || old.color != color;
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.label,
    required this.value,
    this.currency,
    this.note,
    this.trend,
    this.trendLabel,
    this.hidden = false,
    this.onToggleHidden,
  });
  final String label;
  final double value;
  final String? currency;
  final String? note;
  final List<double>? trend;
  final String? trendLabel;
  final bool hidden;
  final VoidCallback? onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Glass(
      strong: true,
      padding: const EdgeInsets.all(space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: CrText.overline(c.inkFaint)),
              if (onToggleHidden != null)
                CrButton(
                  variant: CrButtonVariant.ghost,
                  small: true,
                  icon: 'eye',
                  tooltip: hidden ? 'Mostrar saldo' : 'Ocultar saldo',
                  onPressed: onToggleHidden,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: space2, bottom: space3),
            child: hidden
                ? Text('••••••', style: CrText.amountXl(c.ink))
                : AnimatedMoney(value: value, currency: currency, style: CrText.amountXl(c.ink)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (note != null) Flexible(child: Text(note!, style: CrText.caption(c.inkMuted))) else const SizedBox.shrink(),
              if (trend != null) Sparkline(data: trend!, label: trendLabel ?? 'Tendencia'),
            ],
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.currency,
    this.delta,
    this.invertDelta = false,
    this.icon = 'chart',
    this.tone = Tone.neutral,
    this.note,
  });
  final String label;
  final double value;
  final String? currency;
  final double? delta;
  final bool invertDelta;
  final String icon;
  final Tone tone;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Glass(
      radius: radiusMd,
      lift: true,
      padding: const EdgeInsets.all(space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CrChip(icon, tone: tone),
              if (delta != null) Delta(delta!, invert: invertDelta),
            ],
          ),
          const SizedBox(height: space3),
          Text(label.toUpperCase(), style: CrText.overline(c.inkFaint)),
          AnimatedMoney(value: value, currency: currency, style: CrText.amount(c.ink)),
          if (note != null) Text(note!, style: CrText.caption(c.inkMuted)),
        ],
      ),
    );
  }
}

enum TxKind { income, expense, transfer }

TxKind txKind(String type) => switch (type) {
  'income' => TxKind.income,
  'transfer' => TxKind.transfer,
  _ => TxKind.expense,
};

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.kind,
    required this.title,
    this.detail,
    required this.amount,
    this.currency,
    this.actions,
    this.first = false,
    this.index = 0,
  });
  final TxKind kind;
  final String title;
  final String? detail;
  final double amount;
  final String? currency;
  final Widget? actions;
  final bool first;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final signed = kind == TxKind.expense ? -amount : amount;
    final icon = switch (kind) {
      TxKind.income => 'salary',
      TxKind.expense => 'card',
      TxKind.transfer => 'swap',
    };
    final tone = switch (kind) {
      TxKind.income => Tone.brand,
      TxKind.transfer => Tone.amber,
      _ => Tone.neutral,
    };
    final amountText = Text(
      formatMoney(signed, currency, kind == TxKind.income),
      textAlign: TextAlign.right,
      style: CrText.amountSm(kind == TxKind.income ? c.positive : c.ink),
    );
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: CrText.body(c.ink)),
        if (detail != null) Text(detail!, style: CrText.caption(c.inkMuted)),
      ],
    );
    return FadeIn(
      delay: Duration(milliseconds: 40 * math.min(index, 4)),
      child: Container(
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: c.hairline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
        child: LayoutBuilder(
          builder: (context, box) {
            // En pantallas estrechas las acciones pasan a su propia línea, alineadas a la derecha.
            final narrow = box.maxWidth < 528;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CrChip(icon, tone: tone),
                    const SizedBox(width: space3),
                    Expanded(child: main),
                    const SizedBox(width: space3),
                    amountText,
                    if (actions != null && !narrow) ...[const SizedBox(width: space3), actions!],
                  ],
                ),
                if (actions != null && narrow)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: space1),
                      child: actions,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fila de lista con contenido libre y los mismos separadores que [TransactionRow].
class RowSplit extends StatelessWidget {
  const RowSplit({super.key, required this.children, this.first = false, this.archived = false, this.index = 0});
  final List<Widget> children;
  final bool first;
  final bool archived;
  final int index;

  @override
  Widget build(BuildContext context) => FadeIn(
    delay: Duration(milliseconds: 40 * math.min(index, 4)),
    child: Opacity(
      opacity: archived ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: context.c.hairline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: space3,
          runSpacing: space2,
          children: children,
        ),
      ),
    ),
  );
}

class GlassList extends StatelessWidget {
  const GlassList({super.key, required this.children, this.label});
  final List<Widget> children;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Glass(
      radius: radiusMd,
      padding: const EdgeInsets.symmetric(vertical: space1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.label, required this.spent, required this.limit, this.currency, this.actions});
  final String label;
  final double spent, limit;
  final String? currency;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ratio = limit > 0 ? spent / limit : 0.0;
    final over = ratio > 1;
    final warn = ratio >= 0.8 && !over;
    final track = over ? c.negativeSoft : (warn ? c.amberSoft : c.brandSoft);
    final fill = over ? c.negative : (warn ? c.amber : c.brand);
    final note = over ? 'Excedido en ${formatMoney(spent - limit, currency)}' : 'Quedan ${formatMoney(limit - spent, currency)}';
    return Glass(
      radius: radiusMd,
      lift: true,
      padding: const EdgeInsets.all(space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: CrText.body(c.ink))),
              const SizedBox(width: space3),
              Text('${formatMoney(spent, currency)} / ${formatMoney(limit, currency)}', style: CrText.label(c.inkMuted)),
            ],
          ),
          const SizedBox(height: space2),
          Semantics(
            label: label,
            value: '${(ratio.clamp(0, 1) * 100).round()} %',
            child: Container(
              height: 8,
              decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(radiusPill)),
              clipBehavior: Clip.antiAlias,
              child: GrowBar(ratio: ratio, color: fill),
            ),
          ),
          const SizedBox(height: space2),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${(ratio * 100).round()} % · $note', style: CrText.caption(c.inkMuted)),
              ?actions,
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.label,
    required this.saved,
    required this.target,
    this.currency,
    this.achieved = false,
    this.note,
    this.actions,
  });
  final String label;
  final double saved, target;
  final String? currency;
  final bool achieved;
  final String? note;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ratio = target > 0 ? saved / target : 0.0;
    return Glass(
      radius: radiusMd,
      lift: true,
      borderColor: achieved ? c.brand : null,
      padding: const EdgeInsets.all(space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: CrText.body(c.ink))),
              const SizedBox(width: space3),
              if (achieved)
                const CrBadge('Lograda', tone: Tone.positive, icon: 'check')
              else
                Text('${(ratio.clamp(0, 1) * 100).round()} %', style: CrText.label(c.inkMuted)),
            ],
          ),
          const SizedBox(height: space2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              AnimatedMoney(value: saved, currency: currency, style: CrText.amount(c.ink)),
              Text(' de ${formatMoney(target, currency)}', style: CrText.label(c.inkMuted)),
            ],
          ),
          const SizedBox(height: space2),
          Semantics(
            label: label,
            value: '${(ratio.clamp(0, 1) * 100).round()} %',
            child: Container(
              height: 8,
              decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(radiusPill)),
              clipBehavior: Clip.antiAlias,
              child: GrowBar(ratio: ratio, color: c.brand),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: space2),
              child: Text(note!, style: CrText.caption(c.inkMuted)),
            ),
          if (actions != null)
            Padding(
              padding: const EdgeInsets.only(top: space1),
              child: Wrap(spacing: space2, runSpacing: space2, children: actions!),
            ),
        ],
      ),
    );
  }
}

/// Esqueleto de carga con brillo que recorre (`.cr-skeleton`).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.lines = 3, this.height = 56});
  final int lines;
  final double height;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Cargando…',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Column(
          children: [
            for (var i = 0; i < widget.lines; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == widget.lines - 1 ? 0 : space3),
                child: Container(
                  height: widget.height,
                  constraints: const BoxConstraints(minHeight: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radiusMd),
                    gradient: LinearGradient(
                      begin: Alignment(-2 + 4 * _c.value - 1, 0),
                      end: Alignment(-2 + 4 * _c.value + 1, 0),
                      colors: [c.glass, c.glassStrong, c.glass],
                      stops: const [0.3, 0.5, 0.7],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dona de participación con segmentos que se dibujan al aparecer.
class Donut extends StatelessWidget {
  const Donut({super.key, required this.values, required this.label, this.size = 132});
  final List<double> values;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colors = [c.brand, c.amber, c.negative, c.inkMuted];
    return Semantics(
      label: label,
      image: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
        curve: crEase,
        builder: (context, t, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _DonutPainter(values, colors, c.hairline, t)),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors, this.track, this.t);
  final List<double> values;
  final List<Color> colors;
  final Color track;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 5 / 42;
    final r = size.width * 15.9155 / 42;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, r, paint..color = track);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final pct = values[i] / total;
      final gap = 0.006;
      final sweep = math.max(pct - gap, 0.0001) * 2 * math.pi * t;
      final color = colors[i % colors.length];
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        paint..color = (i < colors.length ? color : color.withValues(alpha: 0.55)).withValues(alpha: (i < colors.length ? 1 : 0.55) * t),
      );
      start += pct * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.t != t || old.values != values || old.track != track;
}

/// Medidor circular de «Disponible hoy»: el arco se llena en 1 s.
class Gauge extends StatelessWidget {
  const Gauge({super.key, required this.ratio, required this.danger, this.size = 120});
  final double ratio;
  final bool danger;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final filled = ratio.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: context.reduceMotion ? filled : 0, end: filled),
      duration: context.reduceMotion ? Duration.zero : const Duration(seconds: 1),
      curve: crEase,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GaugePainter(v, danger ? c.negative : c.brand, danger ? c.negativeSoft : c.brandSoft)),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.ratio, this.color, this.soft);
  final double ratio;
  final Color color, soft;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 120;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: 52 * k);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, 52 * k, paint..color = soft);
    if (ratio > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        ratio * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 * k
          ..strokeCap = StrokeCap.round
          ..color = color
          ..maskFilter = null,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.ratio != ratio || old.color != color;
}

class CrLink extends StatefulWidget {
  const CrLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<CrLink> createState() => _CrLinkState();
}

class _CrLinkState extends State<CrLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w700,
                color: c.brand,
              ),
            ),
            const SizedBox(width: space2),
            AnimatedSlide(
              offset: _hover && !context.reduceMotion ? const Offset(0.25, 0) : Offset.zero,
              duration: const Duration(milliseconds: 250),
              curve: crPopEase,
              child: CrIcon('arrow', size: 16, color: c.brand),
            ),
          ],
        ),
      ),
    );
  }
}
