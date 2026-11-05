import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/glass.dart';
import '../ui/page.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _links = [
  ('/budgets', 'Presupuestos', 'target'),
  ('/recurring', 'Recurrentes', 'swap'),
  ('/waiting', 'Sala de espera', 'calendar'),
  ('/subscriptions', 'Suscripciones', 'search'),
  ('/import', 'Importar CSV', 'download'),
  ('/categories', 'Categorías', 'tag'),
  ('/profile', 'Perfil y ajustes', 'user'),
];

const _legal = [('/terminos', 'Términos y condiciones', 'list'), ('/privacidad', 'Política de privacidad', 'shield')];

/// Versión que se muestra al usuario (la CI la pasa con --dart-define=APP_VERSION=…).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// Licencias de código abierto que usa la app (pantalla estándar de Flutter con el tema de Alvea).
class _LicensesRow extends StatelessWidget {
  const _LicensesRow({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: 'Licencias de código abierto',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showLicensePage(context: context, applicationName: 'Alvea', applicationVersion: appVersion),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hairline)),
          ),
          child: Row(
            children: [
              const CrChip('tag'),
              const SizedBox(width: space3),
              Text('Licencias de código abierto', style: CrText.body(color)),
            ],
          ),
        ),
      ),
    );
  }
}

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
        const SectionTitle('Legal y ayuda'),
        Glass(
          radius: radiusMd,
          padding: const EdgeInsets.symmetric(vertical: space1),
          child: Column(
            children: [
              for (var i = 0; i < _legal.length; i++)
                _MoreRow(first: i == 0, to: _legal[i].$1, label: _legal[i].$2, icon: _legal[i].$3, color: c.ink),
              _LicensesRow(color: c.ink),
            ],
          ),
        ),
        Text('alvea $appVersion · hecho en Colombia', style: CrText.mono(c.inkFaint, size: 11)),
        Align(
          alignment: Alignment.centerLeft,
          child: CrButton(variant: CrButtonVariant.ghost, icon: 'logout', label: 'Cerrar sesión', onPressed: () => context.app.logout()),
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
          // Los textos legales se abren encima (con «Volver»); el resto cambia de sección
          onTap: () => _legal.any((l) => l.$1 == widget.to) ? context.push(widget.to) : context.go(widget.to),
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
