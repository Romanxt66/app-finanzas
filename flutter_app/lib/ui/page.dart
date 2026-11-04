import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/state.dart';

import 'buttons.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

/// Contenido de una pantalla (`.cr-main`): columna centrada de 1080 px, separación de 16 y entrada escalonada.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final staggered = stagger(children);
    final c = context.c;
    // Deslizar hacia abajo recarga los datos de la pantalla (como en las apps nativas)
    return RefreshIndicator(
      color: c.onNeon,
      backgroundColor: c.neon,
      displacement: 24,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        context.app.invalidate();
        await Future<void>.delayed(const Duration(milliseconds: 700));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(space5, space5, space5, wide ? space6 : 96 + MediaQuery.paddingOf(context).bottom + 12),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < staggered.length; i++) ...[if (i > 0) const SizedBox(height: space4), staggered[i]],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dos columnas en pantallas anchas, una en móvil (`.cr-grid-cols`).
class GridCols extends StatelessWidget {
  const GridCols({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: space4), children[i]],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: space4), Expanded(child: children[i])],
      ],
    );
  }
}

/// Rejilla de formulario con columnas de al menos 160 px (`.cr-form-grid`).
class FormGrid extends StatelessWidget {
  const FormGrid({super.key, required this.children, this.minWidth = 160});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = (((box.maxWidth + space3) / (minWidth + space3)).floor()).clamp(1, 6);
      final width = (box.maxWidth - space3 * (cols - 1)) / cols;
      return Wrap(
        spacing: space3,
        runSpacing: space3,
        children: [for (final c in children) SizedBox(width: width, child: c)],
      );
    },
  );
}

/// Pila vertical con separación de 12 (`.cr-stack`).
class Stack12 extends StatelessWidget {
  const Stack12({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: space3), children[i]],
    ],
  );
}

/// Alta plegable: con datos ya creados muestra solo el botón «+ Nuevo…» y el formulario se despliega al
/// tocarlo (el contenido de la pantalla va primero); sin datos, el formulario sale abierto.
class CreateSection extends StatelessWidget {
  const CreateSection({
    super.key,
    required this.label,
    required this.title,
    required this.open,
    required this.onOpenChanged,
    required this.child,
    this.hasData = true,
  });

  /// Texto del botón («Nuevo presupuesto»).
  final String label;

  /// Título de la tarjeta del formulario.
  final String title;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final Widget child;

  /// Sin datos el formulario se muestra siempre (es lo único que hay que hacer).
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final showForm = open || !hasData;
    final c = context.c;
    return AnimatedSize(
      duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
      curve: crEase,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
        switchInCurve: crEase,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.02), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: showForm
            ? CrCard(
                key: const ValueKey('form'),
                title: title,
                action: hasData
                    ? Semantics(
                        button: true,
                        label: 'Cerrar',
                        child: InkResponse(
                          onTap: () => onOpenChanged(false),
                          radius: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.close_rounded, size: 20, color: c.inkMuted),
                          ),
                        ),
                      )
                    : null,
                child: child,
              )
            : Align(
                key: const ValueKey('button'),
                alignment: Alignment.centerLeft,
                child: CrButton(variant: CrButtonVariant.primary, icon: 'plus', label: label, onPressed: () => onOpenChanged(true)),
              ),
      ),
    );
  }
}
