import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/notices.dart';
import '../core/state.dart';
import 'buttons.dart';
import 'dialogs.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

/// Campana de la barra superior con el número de avisos sin leer; abre el panel de avisos.
class NoticeBell extends StatelessWidget {
  const NoticeBell({super.key});

  @override
  Widget build(BuildContext context) {
    final center = context.app.notices;
    final c = context.c;
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final unread = center.unread;
        final urgent = center.items.any((n) => n.urgent && !center.isRead(n));
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CrButton(
              variant: CrButtonVariant.ghost,
              small: true,
              icon: 'bell',
              tooltip: unread == 0 ? 'Avisos' : 'Avisos: $unread sin leer',
              onPressed: () => showNotices(context),
            ),
            if (unread > 0)
              Positioned(
                right: 2,
                top: 2,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: urgent ? c.negative : c.neon,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.bg, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 9.5,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: urgent ? Colors.white : c.onNeon,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Panel con los avisos pendientes; tocar uno lo marca como leído y lleva a su pantalla.
Future<void> showNotices(BuildContext context) {
  final center = context.app.notices;
  final router = GoRouter.of(context);
  center.load();
  return showCrDialog<void>(
    context,
    title: 'Avisos',
    maxWidth: 460,
    builder: (ctx) => ListenableBuilder(
      listenable: center,
      builder: (ctx, _) {
        final c = ctx.c;
        if (center.items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [CrEmpty(center.loaded ? 'Todo en orden: no tienes avisos pendientes.' : 'Cargando avisos…')],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final n in center.items)
              Padding(
                padding: const EdgeInsets.only(bottom: space2),
                child: _NoticeTile(
                  notice: n,
                  read: center.isRead(n),
                  onTap: () {
                    center.markRead(n);
                    Navigator.of(ctx).pop();
                    router.go(n.link);
                  },
                ),
              ),
            if (center.unread > 0)
              Align(
                alignment: Alignment.centerRight,
                child: CrButton(
                  variant: CrButtonVariant.ghost,
                  small: true,
                  icon: 'check',
                  label: 'Marcar todo como leído',
                  onPressed: center.markAllRead,
                ),
              )
            else
              Text('Estás al día.', textAlign: TextAlign.center, style: CrText.caption(c.inkMuted)),
          ],
        );
      },
    ),
  );
}

class _NoticeTile extends StatefulWidget {
  const _NoticeTile({required this.notice, required this.read, required this.onTap});
  final Notice notice;
  final bool read;
  final VoidCallback onTap;

  @override
  State<_NoticeTile> createState() => _NoticeTileState();
}

class _NoticeTileState extends State<_NoticeTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = widget.notice;
    final tone = switch (n.severity) {
      'danger' => c.negative,
      'warning' => c.amber,
      _ => c.neon,
    };
    final icon = switch (n.kind) {
      'recurring_due' => 'calendar',
      'waiting_ready' => 'target',
      _ => 'chart',
    };
    return Semantics(
      button: true,
      label: '${widget.read ? '' : 'Sin leer. '}${n.title}. ${n.body}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(space3),
            decoration: BoxDecoration(
              color: _hover ? c.glassStrong : c.glass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.read ? c.glassBorder : tone.withValues(alpha: 0.55)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: tone.withValues(alpha: 0.16), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: CrIcon(icon, size: 18, color: tone),
                ),
                const SizedBox(width: space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: CrText.body(c.ink).copyWith(fontWeight: widget.read ? FontWeight.w500 : FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(n.body, style: CrText.caption(c.inkMuted)),
                    ],
                  ),
                ),
                if (!widget.read)
                  Padding(
                    padding: const EdgeInsets.only(left: space2, top: 6),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
