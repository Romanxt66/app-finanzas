import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/glass.dart';
import '../ui/page.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _links = [
  ('/budgets', 'Presupuestos', 'target'),
  ('/recurring', 'Recurrentes', 'swap'),
  ('/waiting', 'Sala de espera', 'target'),
  ('/subscriptions', 'Suscripciones', 'search'),
  ('/import', 'Importar CSV', 'download'),
  ('/categories', 'Categorías', 'tag'),
  ('/profile', 'Perfil y ajustes', 'user'),
];

/// Destinos que no caben en la barra de pestañas del móvil.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PageScaffold(
      children: [
        PageHead('Más', headline: 'Todo lo *demás*.'),
        Glass(
          radius: radiusMd,
          padding: const EdgeInsets.symmetric(vertical: space1),
          child: Column(
            children: [
              for (var i = 0; i < _links.length; i++)
                _MoreRow(first: i == 0, to: _links[i].$1, label: _links[i].$2, icon: _links[i].$3, color: c.ink),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreRow extends StatefulWidget {
  const _MoreRow({required this.first, required this.to, required this.label, required this.icon, required this.color});
  final bool first;
  final String to, label, icon;
  final Color color;

  @override
  State<_MoreRow> createState() => _MoreRowState();
}

class _MoreRowState extends State<_MoreRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go(widget.to),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _hover ? c.glass : Colors.transparent,
              border: widget.first ? null : Border(top: BorderSide(color: c.hairline)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
            child: Row(
              children: [
                CrChip(widget.icon),
                const SizedBox(width: space3),
                Text(widget.label, style: CrText.body(widget.color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
