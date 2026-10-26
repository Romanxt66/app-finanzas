import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Curva `cubic-bezier(0.2, 0.7, 0.2, 1)` de Cristal.
const crEase = Cubic(0.2, 0.7, 0.2, 1);
const crPopEase = Cubic(0.2, 0.8, 0.2, 1);

/// Entrada de módulo: sube, crece un poco y aparece (0,52 s). Se escalona con [delay].
/// Si el módulo empieza fuera de la pantalla, espera a que el desplazamiento lo traiga a la vista.
class Rise extends StatefulWidget {
  const Rise({super.key, required this.child, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 520), this.dy = 14});
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double dy;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  Timer? _timer;
  ScrollPosition? _watching;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed || _timer != null || _scheduled) return;
    if (context.reduceMotion) {
      _c.value = 1;
      return;
    }
    _scheduled = true;
    // Se decide tras el primer fotograma, cuando ya se conoce la posición en pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_inView()) {
        _start(widget.delay);
      } else {
        _watching = Scrollable.maybeOf(context)?.position;
        _watching?.addListener(_onScroll);
        if (_watching == null) _start(widget.delay);
      }
    });
  }

  /// Visible si su borde superior ya asoma por la parte baja de la zona desplazable.
  bool _inView() {
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject();
    if (box is! RenderBox || viewport is! RenderBox || !box.attached || !viewport.attached) return true;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top < viewport.size.height - 24;
  }

  void _onScroll() {
    if (!mounted || !_inView()) return;
    _stopWatching();
    _start(Duration.zero);
  }

  void _stopWatching() {
    _watching?.removeListener(_onScroll);
    _watching = null;
  }

  void _start(Duration delay) {
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _stopWatching();
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
        final out = Transform.translate(
          offset: Offset(0, widget.dy * (1 - v)),
          child: Transform.scale(scale: 0.97 + 0.03 * v, alignment: Alignment.topCenter, child: child),
        );
        return Opacity(opacity: v, child: out);
      },
    );
  }
}

/// Paralaje del titular: al desplazar hacia abajo se queda un poco atrás y se desvanece.
/// Solo escucha la posición del desplazamiento; no cambia el diseño de la página.
class ScrollParallax extends StatefulWidget {
  const ScrollParallax({super.key, required this.child, this.factor = 0.3, this.fadeOver = 280});
  final Widget child;
  final double factor;
  final double fadeOver;

  @override
  State<ScrollParallax> createState() => _ScrollParallaxState();
}

class _ScrollParallaxState extends State<ScrollParallax> {
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.reduceMotion ? null : Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _position?.removeListener(_changed);
      _position = next?..addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _position?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _position;
    final px = (p == null || !p.hasPixels) ? 0.0 : p.pixels.clamp(0.0, widget.fadeOver * 2);
    return Opacity(
      opacity: (1 - px / widget.fadeOver).clamp(0.15, 1.0),
      child: Transform.translate(offset: Offset(0, px * widget.factor), child: widget.child),
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
