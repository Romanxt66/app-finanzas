import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/state.dart';
import 'theme.dart';

/// Fondo con resplandores detrás del vidrio.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: c.bg)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.9, -0.95),
                radius: 0.9,
                colors: [c.glowMint, c.glowMint.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.95, 0.95),
                radius: 0.8,
                colors: [c.glowAmber, c.glowAmber.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Módulo de vidrio esmerilado.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.strong = false,
    this.radius = radiusMd,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool strong;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: strong ? c.glassStrong : c.glass,
          shape: RoundedRectangleBorder(
            borderRadius: shape,
            side: BorderSide(color: c.glassBorder),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// Cifra con color según signo (solo dinero con signo).
class Amount extends StatelessWidget {
  const Amount(
    this.value, {
    super.key,
    this.currency,
    this.size = 15,
    this.signed = false,
    this.neutral = false,
  });
  final double value;
  final String? currency;
  final double size;
  final bool signed, neutral;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = neutral
        ? c.ink
        : (value < 0 ? c.negative : (signed && value > 0 ? c.positive : c.ink));
    return Text(
      fmtMoney(value, currency: currency, sign: signed),
      style: TextStyle(
        fontSize: size,
        fontWeight: size > 18 ? FontWeight.w700 : FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(icon, size: 40, color: context.c.inkFaint),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.c.inkMuted),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState(this.error, {super.key, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    error is ApiError
        ? (error as ApiError).message
        : 'Algo salió mal. Inténtalo de nuevo.',
    icon: Icons.cloud_off_outlined,
    action: OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
  );
}

/// Carga asíncrona con esqueleto, error con reintento y recarga por gesto.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;

  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  Future<void> reload() async {
    final next = widget.load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) return ErrorState(snap.error!, onRetry: reload);
      if (!snap.hasData) return const _Skeleton();
      return widget.builder(context, snap.data as T, reload);
    },
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cargando',
    child: Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: context.c.glass,
                borderRadius: BorderRadius.circular(radiusMd),
              ),
            ),
          ),
      ],
    ),
  );
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        e is ApiError ? e.message : 'Algo salió mal. Inténtalo de nuevo.',
      ),
    ),
  );
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String action = 'Eliminar',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Hoja modal con formulario; devuelve true si se guardó algo.
Future<bool> showSheet(
  BuildContext context,
  Widget Function(BuildContext) builder,
) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: SingleChildScrollView(child: builder(ctx)),
    ),
  );
  return res ?? false;
}

/// Botón principal que muestra progreso mientras corre la acción.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed});
  final String label;
  final Future<void> Function() onPressed;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await widget.onPressed();
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      child: _busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.label),
    ),
  );
}

/// Selector de moneda con los códigos que ofrece el backend. El valor queda en [controller].
class CurrencyField extends StatelessWidget {
  const CurrencyField({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final codes = context.app.currencies;
    return DropdownButtonFormField<String>(
      initialValue: codes.contains(controller.text)
          ? controller.text
          : codes.first,
      decoration: const InputDecoration(labelText: 'Moneda'),
      isExpanded: true,
      menuMaxHeight: 320,
      items: [
        for (final c in codes) DropdownMenuItem(value: c, child: Text(c)),
      ],
      onChanged: (v) => controller.text = v ?? controller.text,
    );
  }
}
