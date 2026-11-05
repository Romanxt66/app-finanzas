import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/reminder_center.dart';
import '../core/reminders.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/charge_ticket.dart';
import '../ui/dialogs.dart';
import '../ui/glass.dart';
import '../ui/inputs.dart';
import '../ui/logo.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

// Recordatorios de cobro dentro de la app: la hoja «Lo que se va hoy», el banner cuando un cobro
// no alcanza y la tarjeta de ajustes del perfil. Todo de cristal con el borde iluminado del diseño.

/// Color de acento de cada estado, tomado de la paleta (se lee en claro y en oscuro).
Color statusColor(CrPalette c, ChargeStatus s) => switch (s) {
  ChargeStatus.short => c.amber,
  ChargeStatus.paid => c.positive,
  ChargeStatus.covered => c.neon,
  ChargeStatus.unknown => c.chart2,
};

/// Borde iluminado: blanco arriba a la izquierda que se funde en el color del estado abajo a la derecha.
class RimPainter extends CustomPainter {
  const RimPainter({required this.radius, required this.rim, this.width = 1.5, this.dashed = false});
  final double radius, width;
  final Color rim;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(width / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (dashed) {
      paint.color = rim.withValues(alpha: 0.45);
      for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 10) {
          canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), paint);
        }
      }
      return;
    }
    paint.shader = cssLinear(rect, 135, [const Color(0x8CFFFFFF), const Color(0x14FFFFFF), rim.withValues(alpha: 0.8)], const [0, 0.4, 1]);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(RimPainter old) => old.rim != rim || old.radius != radius || old.dashed != dashed;
}

/// Superficie translúcida con borde iluminado, para dentro de la hoja (que ya desenfoca lo de detrás).
class _Pane extends StatelessWidget {
  const _Pane({required this.child, required this.rim, this.dashed = false});
  final Widget child;
  final Color rim;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.isDark
              ? const [Color(0x24FFFFFF), Color(0x08FFFFFF)]
              : [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0.45)],
        ),
        color: c.isDark ? const Color(0x4D090909) : null,
      ),
      child: CustomPaint(
        foregroundPainter: RimPainter(radius: 18, rim: rim, dashed: dashed),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

/// Círculo con la inicial del cobro (anillo del color del estado).
class _Initial extends StatelessWidget {
  const _Initial(this.name, this.color);
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 2),
      gradient: RadialGradient(
        center: const Alignment(-0.36, -0.48),
        radius: 1,
        colors: [Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.08), color.withValues(alpha: 0.24)],
        stops: const [0, 0.44, 1],
      ),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16)],
    ),
    child: Text(
      name.isEmpty ? '·' : String.fromCharCode(name.runes.first).toUpperCase(),
      style: CrText.heading(context.c.ink).copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

/// Etiqueta con punto de color («te faltan $ 120.000»).
class _StatusChip extends StatelessWidget {
  const _StatusChip(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radiusPill),
      border: Border.all(color: context.c.glassBorder),
      gradient: LinearGradient(colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0.07)]),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: CrText.mono(context.c.ink, size: 11))),
      ],
    ),
  );
}

// ─── Hoja «Lo que se va hoy» ────────────────────────────────────────────────────────────────────

/// Abre la hoja de cobros de [day] (por defecto, hoy).
Future<void> showChargesSheet(BuildContext context, [DateTime? day]) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x8C080808),
  builder: (_) => ChargesSheet(day: dayOf(day ?? DateTime.now())),
);

class ChargesSheet extends StatefulWidget {
  const ChargesSheet({super.key, required this.day});
  final DateTime day;

  @override
  State<ChargesSheet> createState() => _ChargesSheetState();
}

class _ChargesSheetState extends State<ChargesSheet> {
  bool _busy = false;

  Future<void> _remindAt6(ReminderCenter r) async {
    setState(() => _busy = true);
    final d = widget.day;
    final ok = await r.remindAt(d, DateTime(d.year, d.month, d.day, 18));
    if (!mounted) return;
    setState(() => _busy = false);
    context.app.onToast?.call(ok ? 'Te recuerdo a las 6 p. m.' : 'Activa los avisos de Alvea para recordártelo');
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    final r = app.reminders;
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) {
        final now = DateTime.now();
        final isToday = daysBetween(now, widget.day) == 0;
        final list = chargesOn(r.charges, widget.day);
        final tomorrow = isToday ? chargesOn(r.charges, widget.day.add(const Duration(hours: 36))) : const <Charge>[];
        final worst = list.any((x) => x.short)
            ? TicketVariant.short
            : list.isNotEmpty && list.every((x) => x.paid)
            ? TicketVariant.paid
            : TicketVariant.covered;
        final when = isToday ? 'hoy' : whenWord(widget.day, now).replaceFirst('el ', '');
        final canRemind = r.supported && isToday && now.hour < 18 && list.any((x) => !x.paid);
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _SheetGlass(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 18 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: c.inkFaint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(dayHeading(widget.day, list), style: CrText.mono(c.inkMuted, size: 11.5)),
                    const SizedBox(height: 4),
                    CrHeadline('Lo que se va *$when*.', size: 30),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AlviBubble(variant: worst, size: 54, semanticLabel: 'Alvi'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Pane(
                            rim: c.glassBorder,
                            child: Text(alviLine(list, r.accounts, isToday: isToday), style: CrText.label(c.ink)),
                          ),
                        ),
                      ],
                    ),
                    if (!r.loaded) ...[const SizedBox(height: 12), const Skeleton(height: 96)],
                    for (final x in list) ...[const SizedBox(height: 12), _ChargeCard(charge: x, accounts: r.accounts)],
                    if (tomorrow.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('mañana', style: CrText.mono(c.inkMuted, size: 11.5)),
                      for (final x in tomorrow) ...[const SizedBox(height: 10), _ChargeCard(charge: x, accounts: r.accounts)],
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (canRemind) ...[
                          Expanded(
                            child: CrButton(label: 'Recordar a las 6 p. m.', onPressed: _busy ? null : () => _remindAt6(r), expand: true),
                          ),
                          const SizedBox(width: 8),
                        ] else
                          const Spacer(),
                        CrButton(variant: CrButtonVariant.primary, label: 'Listo', onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fondo de la hoja: cristal con desenfoque real (es momentánea), reflejo y borde iluminado.
class _SheetGlass extends StatelessWidget {
  const _SheetGlass({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const radius = BorderRadius.vertical(top: Radius.circular(30));
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: glassFilter(30, 1.7),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: c.isDark ? const Color(0x94080808) : Colors.white.withValues(alpha: 0.82),
            gradient: LinearGradient(
              begin: const Alignment(-1, -1),
              end: const Alignment(0.2, 0.4),
              colors: [
                Colors.white.withValues(alpha: c.isDark ? 0.16 : 0.5),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          child: CustomPaint(foregroundPainter: _TopRim(c.neon), child: child),
        ),
      ),
    );
  }
}

class _TopRim extends CustomPainter {
  const _TopRim(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final path = Path()..addRRect(RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(30), topRight: const Radius.circular(30)));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = cssLinear(
          rect,
          135,
          [const Color(0xB3FFFFFF), const Color(0x1AFFFFFF), accent.withValues(alpha: 0.6)],
          const [0, 0.3, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_TopRim old) => old.accent != accent;
}

class _ChargeCard extends StatelessWidget {
  const _ChargeCard({required this.charge, required this.accounts});
  final Charge charge;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final x = charge;
    final color = statusColor(c, x.status);
    final meta = x.detected
        ? 'detectada en tus movimientos'
        : '${(x.accountName ?? 'pago recurrente').toLowerCase()} · ${x.paid ? 'registrado' : 'se registra solo'}';
    final source = x.short ? suggestSource(x, accounts) : null;
    final Widget bottom = switch (x.status) {
      ChargeStatus.short => Row(
        children: [
          Flexible(child: _StatusChip('te faltan ${formatMoney(x.shortfall, x.currency)}', c.negative)),
          const SizedBox(width: 8),
          if (x.accountId != null)
            CrButton(
              variant: CrButtonVariant.primary,
              small: true,
              label: 'Mover dinero',
              onPressed: () {
                Navigator.of(context).pop();
                GoRouter.of(context).go(moveMoneyRoute(x, from: source));
              },
            ),
        ],
      ),
      ChargeStatus.covered => Align(
        alignment: Alignment.centerLeft,
        child: _StatusChip('alcanza · quedan ${formatMoney(x.remaining!, x.currency)}', c.positive),
      ),
      ChargeStatus.paid => Align(
        alignment: Alignment.centerLeft,
        child: _StatusChip(x.nextDate == null ? 'registrado hoy' : 'registrado · próximo ${formatDate(isoDate(x.nextDate!))}', c.positive),
      ),
      ChargeStatus.unknown when x.detected => Row(
        children: [
          Expanded(
            child: Text(
              'Se cobra ${frequencyWords[x.frequency] ?? 'seguido'} y no está en tus recurrentes.',
              style: CrText.label(c.inkMuted),
            ),
          ),
          const SizedBox(width: 8),
          CrButton(small: true, label: 'Hacerla recurrente', onPressed: () => showMakeRecurring(context, x)),
        ],
      ),
      ChargeStatus.unknown => Text('Se registra sola en la tarjeta.', style: CrText.label(c.inkMuted)),
    };
    return Semantics(
      container: true,
      child: _Pane(
        rim: color,
        dashed: x.detected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Initial(x.name, color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        x.name,
                        style: CrText.heading(c.ink).copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(meta, style: CrText.mono(c.inkMuted, size: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatMoney(x.amount, x.currency.isEmpty ? null : x.currency), style: CrText.amount(c.ink).copyWith(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 10),
            bottom,
          ],
        ),
      ),
    );
  }
}

/// «Hacerla recurrente»: convierte una suscripción detectada en un pago recurrente (elige la cuenta).
Future<void> showMakeRecurring(BuildContext context, Charge charge) async {
  final app = context.app;
  final accounts = app.reminders.accounts.where((a) => !a.archived).toList();
  if (accounts.isEmpty) return;
  final same = accounts.where((a) => a.currency == charge.currency).toList();
  var account = (same.isNotEmpty ? same : accounts).first.id;
  Object? error;
  var busy = false;
  await showCrDialog<void>(
    context,
    title: 'Hacer recurrente «${charge.name}»',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Se registrará sola ${frequencyWords[charge.frequency] ?? ''} por ${formatMoney(charge.amount, charge.currency)}, '
            'empezando el ${formatDate(isoDate(charge.date))}, y te avisaré antes de cada cobro.',
            style: CrText.label(ctx.c.inkMuted),
          ),
          const SizedBox(height: space3),
          CrSelect<String>(
            label: '¿De qué cuenta sale?',
            value: account,
            options: [for (final a in accounts) (a.id, '${a.name} (${a.currency})')],
            onChanged: (v) => setState(() => account = v),
          ),
          ErrorText(error),
          const SizedBox(height: space3),
          Wrap(
            spacing: space3,
            runSpacing: space3,
            children: [
              CrButton(
                variant: CrButtonVariant.primary,
                label: 'Hacerla recurrente',
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await app.data.post('/recurring', {
                            'type': 'expense',
                            'account_id': account,
                            'amount': charge.amount.toStringAsFixed(2),
                            'description': charge.name,
                            'frequency': frequencyWords.containsKey(charge.frequency) ? charge.frequency : 'monthly',
                            'start_date': isoDate(charge.date),
                          }, '${charge.name} ya es un pago recurrente');
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (e) {
                          setState(() {
                            error = e;
                            busy = false;
                          });
                        }
                      },
              ),
              CrButton(variant: CrButtonVariant.ghost, label: 'Cancelar', onPressed: () => Navigator.of(ctx).pop()),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── Banner «no alcanza» ────────────────────────────────────────────────────────────────────────

/// Aviso de cristal en el resumen cuando un cobro de hoy o mañana no alcanza.
class ChargeAlertBanner extends StatelessWidget {
  const ChargeAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.app.reminders;
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) {
        final x = r.alert;
        if (x == null) return const SizedBox.shrink();
        final c = context.c;
        final today = daysBetween(DateTime.now(), x.date) == 0;
        final source = suggestSource(x, r.accounts);
        return Semantics(
          container: true,
          liveRegion: true,
          child: Glass(
            borderColor: Colors.transparent,
            padding: EdgeInsets.zero,
            onTap: () => showChargesSheet(context, x.date),
            child: CustomPaint(
              foregroundPainter: RimPainter(radius: radiusLg, rim: c.amber),
              child: Padding(
                padding: const EdgeInsets.all(space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AlviBubble(variant: TicketVariant.short, size: 62, semanticLabel: 'Alvi preocupada'),
                        const SizedBox(width: space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'cobro de ${today ? 'hoy' : 'mañana'} · ${(x.accountName ?? '').toLowerCase()}',
                                style: CrText.mono(c.amber, size: 11.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${x.name} se cobra ${today ? 'hoy' : 'mañana'} y no te alcanza',
                                style: CrText.heading(c.ink).copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text.rich(
                                TextSpan(
                                  style: CrText.label(c.inkMuted),
                                  children: [
                                    const TextSpan(text: 'Faltan '),
                                    TextSpan(
                                      text: formatMoney(x.shortfall, x.currency),
                                      style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
                                    ),
                                    TextSpan(text: ' en ${x.accountName ?? 'la cuenta'} para cubrir ${formatMoney(x.amount, x.currency)}.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: space3),
                    Row(
                      children: [
                        Expanded(
                          child: CrButton(
                            variant: CrButtonVariant.primary,
                            label: 'Mover dinero',
                            expand: true,
                            onPressed: x.accountId == null ? null : () => context.go(moveMoneyRoute(x, from: source)),
                          ),
                        ),
                        const SizedBox(width: space2),
                        CrButton(label: 'Más tarde', onPressed: () => r.dismiss(x)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Ajustes en el perfil ───────────────────────────────────────────────────────────────────────

/// Interruptor de cristal (encendido en neón).
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({super.key, required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduce = context.reduceMotion;
    return Semantics(
      toggled: value,
      label: label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduce ? 0 : 220),
            width: 52,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radiusPill),
              color: value ? c.neon : c.glassStrong,
              border: Border.all(color: value ? Colors.white.withValues(alpha: 0.5) : c.glassBorder),
              boxShadow: value ? [BoxShadow(color: c.neonGlow, blurRadius: 16)] : null,
            ),
            child: AnimatedAlign(
              duration: Duration(milliseconds: reduce ? 0 : 220),
              curve: crEase,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    colors: value ? const [Colors.white, Color(0xFFDEDEDE)] : const [Color(0xFFE4E4E4), Color(0xFFB6B6B6)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta «Recordatorios de cobro» del perfil (solo en la app de Android, que es donde se programan).
class ReminderSettingsCard extends StatefulWidget {
  const ReminderSettingsCard({super.key});

  @override
  State<ReminderSettingsCard> createState() => _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends State<ReminderSettingsCard> {
  bool _testing = false;

  Future<void> _test(ReminderCenter r) async {
    setState(() => _testing = true);
    final ok = await r.showTest();
    if (!mounted) return;
    setState(() => _testing = false);
    if (!ok) context.app.onToast?.call('Activa los avisos de Alvea en los ajustes del teléfono');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = context.app.reminders;
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) {
        final s = r.settings;
        void set(ReminderSettings next) => r.update(next);
        return CrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recordatorios de cobro', style: CrText.heading(c.ink).copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('De tus recurrentes y suscripciones, antes de que se cobren.', style: CrText.label(c.inkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: space3),
                  GlassSwitch(
                    value: s.enabled,
                    label: 'Recordatorios de cobro',
                    onChanged: (v) => set(s.copyWith(enabled: v)),
                  ),
                ],
              ),
              if (s.enabled && r.permission == false) ...[
                const SizedBox(height: space3),
                Row(
                  children: [
                    Expanded(child: Text('El teléfono no deja a Alvea mostrar avisos.', style: CrText.label(c.amber))),
                    CrButton(
                      small: true,
                      label: 'Permitir',
                      onPressed: () async {
                        if (!await r.requestPermission()) await r.openSystemSettings();
                      },
                    ),
                  ],
                ),
              ],
              if (!s.enabled) ...[
                const SizedBox(height: space3),
                Text('Sin recordatorios: los cobros seguirán apareciendo en la campana de avisos.', style: CrText.label(c.inkMuted)),
              ] else ...[
                const SizedBox(height: space4),
                Text('cuándo', style: CrText.mono(c.inkMuted, size: 11.5)),
                const SizedBox(height: space2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CrSegmented<ReminderWhen>(
                    options: [for (final w in ReminderWhen.values) (w, w.label)],
                    value: s.when,
                    onChanged: (v) => set(s.copyWith(when: v)),
                  ),
                ),
                const SizedBox(height: space3),
                Text('a qué hora', style: CrText.mono(c.inkMuted, size: 11.5)),
                const SizedBox(height: space2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CrSegmented<int>(
                    options: [for (final h in ReminderSettings.hours) (h, hourLabel(h))],
                    value: s.hour,
                    onChanged: (v) => set(s.copyWith(hour: v)),
                  ),
                ),
                const SizedBox(height: space3),
                Text('qué recordar · privacidad', style: CrText.mono(c.inkMuted, size: 11.5)),
                CrCheckbox(
                  value: s.recurring,
                  onChanged: (v) => set(s.copyWith(recurring: v)),
                  label: 'Pagos recurrentes (arriendo, servicios…)',
                ),
                CrCheckbox(
                  value: s.subscriptions,
                  onChanged: (v) => set(s.copyWith(subscriptions: v)),
                  label: 'Suscripciones detectadas',
                ),
                CrCheckbox(
                  value: s.hideAmounts,
                  onChanged: (v) => set(s.copyWith(hideAmounts: v)),
                  label: 'Ocultar el contenido en la pantalla de bloqueo',
                ),
                const SizedBox(height: space3),
                Text('así se verá', style: CrText.mono(c.inkMuted, size: 11.5)),
                const SizedBox(height: space2),
                NotificationPreview(reminder: r.previewReminder(), hidden: s.hideAmounts, hour: s.hour),
              ],
              const SizedBox(height: space4),
              Align(
                alignment: Alignment.centerLeft,
                child: CrButton(label: 'Probar un aviso', icon: 'bell', onPressed: _testing || !s.enabled ? null : () => _test(r)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Vista previa del aviso tal como lo dibuja el sistema: cabecera de Alvea, texto, Alvi y la tarjeta.
class NotificationPreview extends StatelessWidget {
  const NotificationPreview({super.key, required this.reminder, required this.hidden, required this.hour});
  final PlannedReminder reminder;
  final bool hidden;
  final int hour;

  @override
  Widget build(BuildContext context) {
    final ticket = reminder.ticket;
    final short = reminder.alert;
    const ink = Color(0xFFF3F3F3);
    const muted = Color(0xFFCCCCCC);
    return Semantics(
      label: hidden
          ? 'Vista previa: en la pantalla de bloqueo solo se ve que hay un aviso de Alvea'
          : 'Vista previa del aviso: ${reminder.title}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: const Color(0xF5262626), borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: short ? const Color(0xFF626262) : const Color(0xFF434343),
                            ),
                            child: const AlveaLogo(size: 16, background: false),
                          ),
                          const SizedBox(width: 8),
                          Text('Alvea · ${hourLabel(hour)}', style: CrText.label(muted).copyWith(fontSize: 12.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(hidden ? 'Alvea' : reminder.title, style: CrText.heading(ink).copyWith(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        hidden ? 'Contenido oculto: desbloquea el teléfono para ver de qué es y cuánto.' : reminder.body,
                        style: CrText.label(muted),
                      ),
                    ],
                  ),
                ),
                if (!hidden && ticket != null) ...[const SizedBox(width: 12), AlviBubble(variant: ticket.variant, size: 48)],
              ],
            ),
            if (!hidden && ticket != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ChargeTicket(data: ticket),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Si en este dispositivo se programan avisos (la app de Android).
bool get remindersOnDevice => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
