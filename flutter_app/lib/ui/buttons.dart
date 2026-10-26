import 'package:flutter/material.dart';

import 'glass.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';

enum CrButtonVariant { primary, glass, ghost, danger }

/// Botón de Cristal (`.cr-btn`): primario con degradado de marca, vidrio, fantasma o destructivo.
class CrButton extends StatefulWidget {
  const CrButton({
    super.key,
    this.label,
    this.icon,
    this.trailingIcon,
    this.variant = CrButtonVariant.glass,
    this.small = false,
    this.onPressed,
    this.tooltip,
    this.expand = false,
    this.height,
  });
  final String? label;
  final String? icon;
  final String? trailingIcon;
  final CrButtonVariant variant;
  final bool small;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool expand;
  final double? height;

  @override
  State<CrButton> createState() => _CrButtonState();
}

class _CrButtonState extends State<CrButton> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = widget.onPressed != null;
    final v = widget.variant;
    final h = widget.height ?? (widget.small ? 34.0 : 44.0);
    final iconOnly = widget.icon != null && widget.label == null;
    final hover = _hover && enabled;
    final fg = switch (v) {
      CrButtonVariant.primary => c.onBrand,
      CrButtonVariant.glass => c.ink,
      CrButtonVariant.ghost => hover ? c.ink : c.inkMuted,
      CrButtonVariant.danger => c.negative,
    };
    final bg = switch (v) {
      CrButtonVariant.glass => c.glassStrong,
      CrButtonVariant.ghost => hover ? c.glass : null,
      CrButtonVariant.danger => hover ? c.negativeSoft : null,
      CrButtonVariant.primary => null,
    };
    final shape = BorderRadius.circular(radiusSm);
    var gradient = v == CrButtonVariant.primary
        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.brandFill, c.brandFill2])
        : null;
    if (gradient != null && hover) {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(c.brandFill, Colors.white, 0.12)!, Color.lerp(c.brandFill2, Colors.white, 0.12)!],
      );
    }
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) CrIcon(widget.icon!, size: 18, color: fg),
        if (widget.icon != null && widget.label != null) const SizedBox(width: space2),
        if (widget.label != null)
          Flexible(
            child: Text(
              widget.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
                fontSize: widget.small ? 13 : 14,
                height: 1,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: space2),
          AnimatedSlide(
            offset: hover && !context.reduceMotion ? const Offset(4 / 18, 0) : Offset.zero,
            duration: const Duration(milliseconds: 250),
            curve: crPopEase,
            child: CrIcon(widget.trailingIcon!, size: 18, color: fg),
          ),
        ],
      ],
    );
    Widget btn = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: h,
      width: iconOnly ? 44 : null,
      padding: iconOnly ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: widget.small ? space4 : space5),
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        borderRadius: shape,
        border: Border.all(color: v == CrButtonVariant.glass ? c.glassBorder : Colors.transparent),
        boxShadow: v == CrButtonVariant.primary ? [c.shadowBrand] : null,
      ),
      foregroundDecoration: _focused
          ? BoxDecoration(
              borderRadius: shape,
              border: Border.all(color: c.focus, width: 2),
            )
          : null,
      child: Center(widthFactor: 1, child: content),
    );
    if (v == CrButtonVariant.primary) {
      btn = CustomPaint(foregroundPainter: _TopSheen(shape), child: btn);
    }
    if (v == CrButtonVariant.glass) {
      btn = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(filter: glassFilter(blurMd, 1), child: btn),
      );
    }
    if (hover && v == CrButtonVariant.primary && !context.reduceMotion) {
      btn = Transform.translate(offset: const Offset(0, -1), child: btn);
    }
    btn = Opacity(opacity: enabled ? 1 : 0.5, child: btn);
    btn = PressScale(enabled: enabled, scale: v == CrButtonVariant.primary ? 0.98 : 0.97, child: btn);
    btn = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onShowHoverHighlight: (h) => setState(() => _hover = h),
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onPressed, child: btn),
    );
    if (widget.expand) btn = SizedBox(width: double.infinity, child: btn);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip ?? widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: widget.tooltip == null ? btn : Tooltip(message: widget.tooltip!, child: btn),
    );
  }
}

class _TopSheen extends CustomPainter {
  _TopSheen(this.shape);
  final BorderRadius shape;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = shape.toRRect(Offset.zero & size);
    canvas.clipRRect(rrect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRRect(rrect), Path()..addRRect(rrect.shift(const Offset(0, 1)))),
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.28),
    );
  }

  @override
  bool shouldRepaint(_TopSheen old) => false;
}
