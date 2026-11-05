import 'package:flutter/material.dart';

import '../core/state.dart';
import '../ui/accent.dart';
import '../ui/buttons.dart';
import '../ui/glass.dart';
import '../ui/icons.dart';
import '../ui/inputs.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Perfil → Apariencia: tema, tono de los grises, luz del fondo (con vista previa en vivo) y animaciones.
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final custom = !app.accent.isDefault || app.glow != GlowLevel.normal;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: space2, bottom: space2),
      child: Text(text, style: CrText.mono(c.inkMuted, size: 11.5)),
    );
    return CrCard(
      title: 'Apariencia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('tema'),
          Align(
            alignment: Alignment.centerLeft,
            child: CrSegmented<ThemeMode>(
              options: const [(ThemeMode.system, 'Automático'), (ThemeMode.light, 'Claro'), (ThemeMode.dark, 'Oscuro')],
              value: app.themeMode,
              onChanged: app.setTheme,
            ),
          ),
          const SizedBox(height: space2),
          label('tono de los grises'),
          Semantics(
            container: true,
            label: 'Tono de los grises',
            child: Wrap(
              spacing: space3,
              runSpacing: space3,
              children: [for (final a in accentChoices) _Swatch(choice: a, selected: a.id == app.accent.id, onTap: () => app.setAccent(a))],
            ),
          ),
          const SizedBox(height: space2),
          label('luz del fondo'),
          Align(
            alignment: Alignment.centerLeft,
            child: CrSegmented<GlowLevel>(
              options: [for (final g in GlowLevel.values) (g, g.label)],
              value: app.glow,
              onChanged: app.setGlow,
            ),
          ),
          const SizedBox(height: space2),
          label('así se ve'),
          const _Preview(),
          const SizedBox(height: space3),
          Align(
            alignment: Alignment.centerLeft,
            child: CrCheckbox(
              value: app.reduceMotion || MediaQuery.disableAnimationsOf(context),
              onChanged: app.setReduceMotion,
              label: 'Reducir animaciones',
            ),
          ),
          if (View.of(context).platformDispatcher.accessibilityFeatures.disableAnimations)
            Text('Tu sistema ya pide reducir el movimiento: Alvea lo respeta.', style: CrText.caption(c.inkMuted)),
          if (custom) ...[
            const SizedBox(height: space3),
            Align(
              alignment: Alignment.centerLeft,
              child: CrButton(
                variant: CrButtonVariant.ghost,
                small: true,
                icon: 'restore',
                label: 'Volver al estilo original',
                onPressed: () {
                  app.setAccent(fuchsiaAccent);
                  app.setGlow(GlowLevel.normal);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Muestra de color: círculo brillante con su nombre; la elegida lleva anillo, halo y ✓.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.choice, required this.selected, required this.onTap});
  final AccentChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = choice.swatch;
    final ms = context.reduceMotion ? 0 : 220;
    return Semantics(
      button: true,
      selected: selected,
      label: choice.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: PressScale(
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: ms),
                    curve: crEase,
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? color : c.glassBorder, width: selected ? 2 : 1),
                      boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 16)] : null,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.45),
                          colors: [Color.lerp(color, Colors.white, 0.55)!, color, Color.lerp(color, Colors.black, 0.25)!],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: ms),
                        opacity: selected ? 1 : 0,
                        child: const Center(child: CrIcon('check', size: 18, color: Color(0xFF0B0B0B), stroke: 2.6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    choice.label,
                    style: CrText.label(selected ? c.ink : c.inkMuted)
                        .copyWith(fontSize: 12, fontWeight: selected ? FontWeight.w700 : null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vista previa en vivo: un trocito de la app con el acento y la luz elegidos.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: Glass(
        padding: const EdgeInsets.all(space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CrTag('resumen', pulse: true),
            const SizedBox(height: space2),
            const CrHeadline('Tu dinero, *claro*.', size: 24),
            const SizedBox(height: space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, h) in const [0.35, 0.6, 0.45, 0.8, 0.55, 1.0].indexed) ...[
                  Expanded(
                    child: Container(
                      height: 44 * h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [c.neon, c.neon.withValues(alpha: 0.25)],
                        ),
                        boxShadow: i == 5 ? [BoxShadow(color: c.neonGlow, blurRadius: 12)] : null,
                      ),
                    ),
                  ),
                  if (i < 5) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: space3),
            Wrap(
              spacing: space2,
              runSpacing: space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CrButton(variant: CrButtonVariant.primary, small: true, label: 'Guardar', onPressed: () {}),
                const CrBadge('meta lograda', tone: Tone.brand),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
