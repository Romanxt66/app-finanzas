import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/reference.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/glass.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/online.dart';
import '../ui/theme.dart';

class NavItem {
  const NavItem(this.to, this.label, this.icon, {this.end = false});
  final String to, label, icon;
  final bool end;
}

const desktopNav = [
  NavItem('/', 'Inicio', 'home', end: true),
  NavItem('/transactions', 'Movimientos', 'list'),
  NavItem('/accounts', 'Cuentas', 'wallet'),
  NavItem('/budgets', 'Presupuestos', 'target'),
  NavItem('/goals', 'Metas', 'chart'),
  NavItem('/recurring', 'Recurrentes', 'swap'),
  NavItem('/categories', 'Categorías', 'tag'),
];

// En móvil caben cinco pestañas: lo demás vive en «Más».
const mobileNav = [
  NavItem('/', 'Inicio', 'home', end: true),
  NavItem('/transactions', 'Movimientos', 'list'),
  NavItem('/accounts', 'Cuentas', 'wallet'),
  NavItem('/goals', 'Metas', 'chart'),
  NavItem('/more', 'Más', 'plus'),
];

bool _active(NavItem item, String location) => item.end ? location == item.to : (location == item.to || location.startsWith('${item.to}/'));

/// Marco de la app autenticada: barra superior de vidrio, contenido y barra de pestañas flotante.
class AppLayout extends StatefulWidget {
  const AppLayout({super.key, required this.child});
  final Widget child;

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  final _online = Online();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.app.runDueRecurring());
  }

  @override
  void dispose() {
    _online.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final location = GoRouterState.of(context).uri.path;
    return RefLoader(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(location: location),
                ValueListenableBuilder<bool>(
                  valueListenable: _online,
                  builder: (context, online, _) => online ? const SizedBox.shrink() : const _OfflineBanner(),
                ),
                Expanded(
                  child: KeyedSubtree(key: ValueKey(location), child: widget.child),
                ),
              ],
            ),
            if (!wide)
              Positioned(
                left: space3,
                right: space3,
                bottom: space3 + MediaQuery.paddingOf(context).bottom,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _TabBar(location: location),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Rise(
      dy: 0,
      duration: const Duration(milliseconds: 300),
      child: Semantics(
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(space3, space3, space3, 0),
          padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space2),
          decoration: BoxDecoration(color: c.amberSoft, borderRadius: BorderRadius.circular(radiusPill)),
          child: Text(
            'Sin conexión: puedes ver lo ya cargado, pero los cambios no se guardarán hasta volver a conectarte.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: fontFallback,
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w600,
              color: c.amber,
            ),
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusSm),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.brandFill, c.brandFill2]),
        boxShadow: [c.shadowBrand],
      ),
      child: Center(child: CrIcon('wallet', size: 18, color: c.onBrand)),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final wide = context.isWide;
    final width = MediaQuery.sizeOf(context).width;
    final labelsAll = width >= 1360;
    final choiceLabel = switch (app.themeMode) {
      ThemeMode.system => 'automático',
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'oscuro',
    };
    return SafeArea(
      bottom: false,
      child: Glass(
        blur: blurLg,
        margin: const EdgeInsets.fromLTRB(space3, space3, space3, 0),
        padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space2),
        child: Row(
          children: [
            const BrandMark(),
            const SizedBox(width: space2),
            Text(
              'Alvea',
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
                fontSize: 18,
                height: 24 / 18,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            if (wide) ...[
              const SizedBox(width: space4),
              for (final item in desktopNav)
                _NavPill(item: item, active: _active(item, location), showLabel: labelsAll || _active(item, location)),
            ],
            const Spacer(),
            if (wide) _UserLink(name: app.user?.fullName ?? '', showName: labelsAll, active: location == '/profile'),
            CrButton(
              variant: CrButtonVariant.ghost,
              small: true,
              icon: app.themeMode == ThemeMode.dark ? 'moon' : 'sun',
              tooltip: 'Tema: $choiceLabel. Cambiar',
              onPressed: app.cycleTheme,
            ),
            const SizedBox(width: space1),
            CrButton(variant: CrButtonVariant.ghost, small: true, icon: 'logout', label: 'Salir', onPressed: () => app.logout()),
          ],
        ),
      ),
    );
  }
}

class _NavPill extends StatefulWidget {
  const _NavPill({required this.item, required this.active, required this.showLabel});
  final NavItem item;
  final bool active, showLabel;

  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = widget.active;
    return Padding(
      padding: const EdgeInsets.only(right: space1),
      child: Semantics(
        button: true,
        selected: active,
        label: widget.item.label,
        child: Tooltip(
          message: widget.item.label,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              onTap: () => context.go(widget.item.to),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                padding: EdgeInsets.symmetric(horizontal: widget.showLabel ? space4 : space3),
                decoration: BoxDecoration(
                  color: active ? c.glassStrong : (_hover ? c.glass : Colors.transparent),
                  borderRadius: BorderRadius.circular(radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CrIcon(widget.item.icon, size: 18, color: active || _hover ? c.ink : c.inkMuted),
                    if (widget.showLabel) ...[
                      const SizedBox(width: space2),
                      Text(
                        widget.item.label,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontFamilyFallback: fontFallback,
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: active || _hover ? c.ink : c.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserLink extends StatefulWidget {
  const _UserLink({required this.name, required this.showName, required this.active});
  final String name;
  final bool showName, active;

  @override
  State<_UserLink> createState() => _UserLinkState();
}

class _UserLinkState extends State<_UserLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: 'Perfil',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => context.go('/profile'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: space3, vertical: space2),
            decoration: BoxDecoration(color: _hover ? c.glass : Colors.transparent, borderRadius: BorderRadius.circular(radiusPill)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CrIcon('user', size: 18, color: _hover ? c.ink : c.inkMuted),
                if (widget.showName) ...[
                  const SizedBox(width: space2),
                  Text(widget.name, style: CrText.label(_hover ? c.ink : c.inkMuted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Navegación principal',
    child: Glass(
      blur: blurLg,
      padding: const EdgeInsets.all(space2),
      child: Row(
        children: [
          for (final item in mobileNav)
            Expanded(
              child: _Tab(item: item, active: _active(item, location)),
            ),
        ],
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.active});
  final NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = active ? c.brand : c.inkFaint;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: PressScale(
        scale: 0.95,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go(item.to),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: space2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSlide(
                  offset: active && !context.reduceMotion ? const Offset(0, -2 / 22) : Offset.zero,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.ease,
                  child: AnimatedScale(
                    scale: active && !context.reduceMotion ? 1.08 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: CrIcon(item.icon, size: 22, color: color),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
