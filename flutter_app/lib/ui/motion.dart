import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Curva `cubic-bezier(0.2, 0.7, 0.2, 1)` de Cristal.
const crEase = Cubic(0.2, 0.7, 0.2, 1);
const crPopEase = Cubic(0.2, 0.8, 0.2, 1);

/// Entrada de módulo: sube, aparece y se enfoca (0,52 s). Se escalona con [delay].
class Rise extends StatefulWidget {
  const Rise({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.dy = 14,
    this.blur = 6,
  });
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double dy;

  /// Desenfoque inicial (píxeles); 0 lo desactiva.
  final double blur;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed && _timer == null) {
      if (context.reduceMotion) {
        _c.value = 1;
      } else if (widget.delay == Duration.zero) {
        _c.forward();
      } else {
        _timer = Timer(widget.delay, () {
          if (mounted) _c.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: crEase);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) {
        final v = curved.value.clamp(0.0, 1.0);
        Widget out = Transform.translate(offset: Offset(0, widget.dy * (1 - v)), child: child);
        // Aparece desenfocado y se aclara, como los titulares del diseño «Relay»
        if (widget.blur > 0 && v < 1) {
          final sigma = widget.blur * (1 - v);
          out = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: out);
        }
        return Opacity(opacity: v, child: out);
      },
    );
  }
}

/// Escalona la entrada de los hijos de una pantalla (50 ms por módulo, hasta 250 ms).
List<Widget> stagger(List<Widget> children, {int stepMs = 50, int maxMs = 250}) => [
  for (var i = 0; i < children.length; i++)
    Rise(
      key: children[i].key,
      delay: Duration(milliseconds: (i * stepMs).clamp(0, maxMs)),
      child: children[i],
    ),
];

/// `cr-fade` para filas de listas (0,35 s, retardo de 40 ms por fila hasta 160 ms).
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 350)});
  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed && _timer == null) {
      if (context.reduceMotion) {
        _c.value = 1;
      } else {
        _timer = Timer(widget.delay, () {
          if (mounted) _c.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _c, curve: Curves.ease),
    child: widget.child,
  );
}

/// Barra de progreso que crece desde cero (`cr-fill`: 0,7 s, retardo 0,15 s).
class GrowBar extends StatelessWidget {
  const GrowBar({super.key, required this.ratio, required this.color, this.height = 8, this.glow = false});
  final double ratio;
  final Color color;
  final double height;

  /// Halo de luz del mismo color alrededor de la barra.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final r = ratio.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: context.reduceMotion ? r : 0, end: r),
      duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
      curve: crEase,
      builder: (context, v, _) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radiusPill),
            boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 10)] : null,
          ),
        ),
      ),
    );
  }
}

/// Cifra que cuenta hasta su valor (0,7 s, ease-out cúbico), como `useCountUp`.
class CountUp extends StatefulWidget {
  const CountUp({super.key, required this.value, required this.builder});
  final double value;
  final Widget Function(BuildContext context, double value) builder;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  double _from = 0;
  double _to = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _to = widget.value;
      if (context.reduceMotion) {
        _from = _to;
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void didUpdateWidget(CountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _from + (_to - _from) * Curves.easeOutCubic.transform(_c.value);
      _to = widget.value;
      if (context.reduceMotion) {
        _from = _to;
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final t = Curves.easeOutCubic.transform(_c.value);
      return widget.builder(context, _c.value >= 1 ? _to : _from + (_to - _from) * t);
    },
  );
}

/// Rebote de escala al presionar (`:active { transform: scale(.97) }`).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97, this.enabled = true});
  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => widget.enabled ? setState(() => _down = true) : null,
    onPointerUp: (_) => setState(() => _down = false),
    onPointerCancel: (_) => setState(() => _down = false),
    child: AnimatedScale(
      scale: _down && !context.reduceMotion ? widget.scale : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.ease,
      child: widget.child,
    ),
  );
}
