import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'logo.dart';
import 'motion.dart';
import 'theme.dart';

/// Entrada a la app: el cuadrado de marca crece hasta cubrir la pantalla y se desvanece.
/// Se ve una vez por sesión y no bloquea toques; con «reducir movimiento» no aparece.
class BrandIntro extends StatefulWidget {
  const BrandIntro({super.key});

  static bool _played = false;

  /// Permite volver a verla en los tests.
  @visibleForTesting
  static void reset() => _played = false;

  @override
  State<BrandIntro> createState() => _BrandIntroState();
}

class _BrandIntroState extends State<BrandIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250));
  bool _show = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BrandIntro._played || _show) return;
    BrandIntro._played = true;
    if (context.reduceMotion) return;
    _show = true;
    _c.forward().whenComplete(() {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final c = context.c;
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, box) => AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final grow = crEase.transform((t / 0.55).clamp(0.0, 1.0));
                final fade = Curves.easeOut.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0));
                const base = 76.0;
                final cover = math.sqrt(box.maxWidth * box.maxWidth + box.maxHeight * box.maxHeight) / base;
                final scale = 1 + (cover - 1) * grow;
                return Opacity(
                  opacity: 1 - fade,
                  child: Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: base,
                        height: base,
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            center: Alignment(0, -0.4),
                            radius: 0.8,
                            colors: [Color(0xFF2A0F4A), Color(0xFF140826), Color(0xFF0A0414)],
                            stops: [0, 0.6, 1],
                          ),
                          borderRadius: BorderRadius.circular(22 * (1 - grow) + 4),
                          boxShadow: [BoxShadow(color: c.neonGlow, blurRadius: 40)],
                        ),
                        child: Opacity(
                          opacity: (1 - grow * 2.2).clamp(0.0, 1.0),
                          child: const AlveaLogo(size: base, background: false),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
