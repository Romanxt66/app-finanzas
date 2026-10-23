import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

/// Contenido de una pantalla (`.cr-main`): columna centrada de 1080 px, separación de 16 y entrada escalonada.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final staggered = stagger(children);
    return SingleChildScrollView(
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
