import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'buttons.dart';
import 'glass.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';

/// Diálogo modal de Cristal: velo con desenfoque (0,2 s) y panel que aparece con "pop" (0,25 s).
Future<T?> showCrDialog<T>(BuildContext context, {required WidgetBuilder builder, String? title, double maxWidth = 400}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, _) {
      final c = ctx.c;
      // App nativa: el diálogo sube por encima del teclado (en la web lo hace el navegador)
      final keyboard = kIsWeb ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(space4).copyWith(bottom: space4 + keyboard),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Material(
                type: MaterialType.transparency,
                child: Glass(
                  strong: true,
                  padding: const EdgeInsets.all(space5),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (title != null) ...[
                          Semantics(header: true, child: Text(title, style: CrText.heading(c.ink))),
                          const SizedBox(height: space3),
                        ],
                        builder(ctx),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final fade = CurvedAnimation(
        parent: anim,
        curve: const Interval(0, 0.8, curve: Curves.ease),
      );
      final pop = CurvedAnimation(parent: anim, curve: crEase);
      return Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: fade,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: const ColoredBox(color: Color.fromRGBO(5, 5, 5, 0.55)),
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: pop,
            child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(pop), child: child),
          ),
        ],
      );
    },
  );
}

/// Confirmación destructiva: «Cancelar» + acción roja.
Future<bool> showConfirm(BuildContext context, {required String title, String? body, String confirmLabel = 'Eliminar'}) async {
  final ok = await showCrDialog<bool>(
    context,
    title: title,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (body != null)
          Padding(
            padding: const EdgeInsets.only(top: space2, bottom: space5),
            child: Text(body, style: CrText.body(ctx.c.inkMuted)),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CrButton(label: 'Cancelar', variant: CrButtonVariant.ghost, onPressed: () => Navigator.pop(ctx, false)),
            const SizedBox(width: space2),
            CrButton(label: confirmLabel, variant: CrButtonVariant.danger, onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Avisos (toasts) de éxito: píldora de vidrio con check, 3,8 s, máximo 3 a la vez.
class ToastController extends ChangeNotifier {
  final items = <({int id, String message, String? actionLabel, VoidCallback? onAction})>[];
  int _next = 1;

  void success(String message) => show(message);

  /// Aviso con un botón (p. ej. «Deshacer»); dura algo más para dar tiempo a tocarlo.
  void show(String message, {String? actionLabel, VoidCallback? onAction}) {
    final id = _next++;
    items.add((id: id, message: message, actionLabel: actionLabel, onAction: onAction));
    if (items.length > 3) items.removeAt(0);
    notifyListeners();
    Timer(Duration(milliseconds: onAction == null ? 3800 : 6000), () => dismiss(id));
  }

  void dismiss(int id) {
    items.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}

class ToastScope extends InheritedNotifier<ToastController> {
  const ToastScope({super.key, required ToastController controller, required super.child}) : super(notifier: controller);

  static ToastController of(BuildContext context) => context.getInheritedWidgetOfExactType<ToastScope>()!.notifier!;
}

extension ToastContext on BuildContext {
  ToastController get toast => ToastScope.of(this);
}

class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.controller, required this.child});
  final ToastController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final bottom = wide ? space5 : 96 + MediaQuery.paddingOf(context).bottom;
    return ToastScope(
      controller: controller,
      child: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: ListenableBuilder(
              listenable: controller,
              // Solo recibe toques si algún aviso tiene botón (si no, no tapa la pantalla)
              builder: (context, _) => IgnorePointer(
                ignoring: !controller.items.any((t) => t.onAction != null),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in controller.items)
                        Padding(
                          key: ValueKey(t.id),
                          padding: const EdgeInsets.fromLTRB(space4, 0, space4, space2),
                          child: _ToastBubble(
                            message: t.message,
                            actionLabel: t.actionLabel,
                            onAction: t.onAction == null
                                ? null
                                : () {
                                    controller.dismiss(t.id);
                                    t.onAction!();
                                  },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastBubble extends StatelessWidget {
  const _ToastBubble({required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Rise(
      dy: 12,
      duration: const Duration(milliseconds: 300),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          type: MaterialType.transparency,
          child: Glass(
            strong: true,
            radius: radiusPill,
            padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CrIcon('check', size: 18, color: c.brand),
                const SizedBox(width: space3),
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFallback,
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(width: space3),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: onAction,
                      child: Text(
                        actionLabel ?? 'Deshacer',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontFamilyFallback: fontFallback,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.neon,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
