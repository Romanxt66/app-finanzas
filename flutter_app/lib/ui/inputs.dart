import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'dialogs.dart';
import 'glass.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';

/// Etiqueta + control + mensaje de error (`.cr-field`).
class CrField extends StatelessWidget {
  const CrField({super.key, required this.label, required this.child, this.error});
  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: space1),
          child: Text(label, style: CrText.label(c.inkMuted)),
        ),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: space1),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontFamilyFallback: fontFallback,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w500,
                  color: c.negative,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cara de vidrio de un campo: borde de marca con aro al enfocar, rojo si hay error.
class FieldFace extends StatelessWidget {
  const FieldFace({
    super.key,
    required this.child,
    this.focused = false,
    this.hovered = false,
    this.invalid = false,
    this.left,
    this.right,
    this.lead,
    this.trail,
    this.onTap,
  });
  final Widget child;
  final bool focused, hovered, invalid;
  final double? left, right;
  final Widget? lead;
  final Widget? trail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final border = invalid && !focused
        ? c.negative
        : (focused ? (invalid ? c.negative : c.brand) : (hovered ? c.glassHighlight : c.glassBorder));
    final shape = BorderRadius.circular(radiusSm);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: focused ? [BoxShadow(color: invalid ? c.negativeSoft : c.brandSoft, spreadRadius: 3)] : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: frosted(c, hovered ? c.glassStrong : c.glass),
              borderRadius: shape,
              border: Border.all(color: border),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: left ?? space4, right: right ?? space4),
                  child: child,
                ),
                if (lead != null)
                  Positioned(
                    left: space4,
                    child: IconTheme(
                      data: IconThemeData(color: focused ? c.brand : c.inkMuted),
                      child: lead!,
                    ),
                  ),
                if (trail != null) Positioned(right: space2, child: trail!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CrTextField extends StatefulWidget {
  const CrTextField({
    super.key,
    required this.label,
    this.controller,
    this.error,
    this.icon,
    this.trailing,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.autofillHints,
    this.inputFormatters,
    this.textInputAction,
    this.enabled = true,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController? controller;
  final String? error;
  final String? icon;
  final Widget? trailing;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autofocus;

  @override
  State<CrTextField> createState() => _CrTextFieldState();
}

class _CrTextFieldState extends State<CrTextField> {
  final _focus = FocusNode();
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CrField(
      label: widget.label,
      error: widget.error,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: FieldFace(
          focused: _focus.hasFocus,
          hovered: _hover && widget.enabled,
          invalid: widget.error != null,
          left: widget.icon != null ? 46 : null,
          right: widget.trailing != null ? 48 : null,
          lead: widget.icon == null ? null : CrIcon(widget.icon!, size: 18),
          trail: widget.trailing,
          child: Semantics(
            label: widget.label,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              inputFormatters: widget.inputFormatters,
              maxLength: widget.maxLength,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              cursorColor: c.brand,
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
                fontSize: 15,
                height: 22 / 15,
                fontWeight: FontWeight.w500,
                color: c.ink,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontFamilyFallback: fontFallback,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.inkMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contraseña con candado y botón para mostrarla u ocultarla.
class CrPasswordField extends StatefulWidget {
  const CrPasswordField({
    super.key,
    required this.label,
    this.controller,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.textInputAction,
  });
  final String label;
  final TextEditingController? controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;

  @override
  State<CrPasswordField> createState() => _CrPasswordFieldState();
}

class _CrPasswordFieldState extends State<CrPasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CrTextField(
      label: widget.label,
      controller: widget.controller,
      error: widget.error,
      icon: 'lock',
      obscure: !_visible,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      trailing: Semantics(
        button: true,
        toggled: _visible,
        label: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
        child: _IconToggle(icon: _visible ? 'eyeOff' : 'eye', color: c.inkMuted, onTap: () => setState(() => _visible = !_visible)),
      ),
    );
  }
}

class _IconToggle extends StatefulWidget {
  const _IconToggle({required this.icon, required this.color, required this.onTap});
  final String icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_IconToggle> createState() => _IconToggleState();
}

class _IconToggleState extends State<_IconToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: _hover ? c.glass : Colors.transparent, shape: BoxShape.circle),
          child: Center(child: CrIcon(widget.icon, size: 20, color: _hover ? c.ink : widget.color)),
        ),
      ),
    );
  }
}

class CrCheckbox extends StatefulWidget {
  const CrCheckbox({super.key, required this.value, required this.onChanged, required this.label});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  State<CrCheckbox> createState() => _CrCheckboxState();
}

class _CrCheckboxState extends State<CrCheckbox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = widget.value;
    return Semantics(
      checked: on,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!on),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: on && !context.reduceMotion ? 1.06 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: crPopEase,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: on
                          ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.brandFill, c.brandFill2])
                          : null,
                      color: on ? null : c.glass,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: on ? Colors.transparent : (_hover ? c.glassHighlight : c.glassBorder)),
                    ),
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: on ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: CrIcon('check', size: 14, color: c.onBrand, stroke: 3 * 1.8 / 3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: space3),
                Flexible(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFallback,
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w500,
                      color: c.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Control segmentado de vidrio (`.cr-seg`).
class CrSegmented<T> extends StatelessWidget {
  const CrSegmented({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Glass(
      radius: radiusPill,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Semantics(
              button: true,
              selected: options[i].$1 == value,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onChanged(options[i].$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: space4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: options[i].$1 == value ? c.glassStrong : Colors.transparent,
                      borderRadius: BorderRadius.circular(radiusPill),
                      boxShadow: options[i].$1 == value
                          ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Text(
                      options[i].$2,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontFamilyFallback: fontFallback,
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: options[i].$1 == value ? c.ink : c.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Desplegable de cristal: cara de campo + menú animado (`.cr-select` / `.cr-menu`).
class CrSelect<T> extends StatefulWidget {
  const CrSelect({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.error,
    this.placeholder,
  });
  final String label;
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String? error;
  final String? placeholder;

  @override
  State<CrSelect<T>> createState() => _CrSelectState<T>();
}

class _CrSelectState<T> extends State<CrSelect<T>> {
  final _link = LayerLink();
  final _focus = FocusNode();
  final _faceKey = GlobalKey();
  OverlayEntry? _entry;
  bool _hover = false;
  final _active = ValueNotifier<int>(0);

  bool get _open => _entry != null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _close();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _active.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _selectedIndex => widget.options.indexWhere((o) => o.$1 == widget.value);

  void _close() {
    if (_entry == null) return;
    _entry!.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  void _show() {
    if (_open || widget.options.isEmpty) return;
    _active.value = _selectedIndex >= 0 ? _selectedIndex : 0;
    final box = _faceKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.sizeOf(context);
    final below = screen.height - (origin.dy + size.height) - 18;
    final above = origin.dy - 18;
    final up = below < 180 && above > below;
    final maxHeight = (up ? above : below).clamp(120.0, 288.0);
    _entry = OverlayEntry(
      builder: (_) => _SelectMenu<T>(
        link: _link,
        width: size.width,
        faceHeight: size.height,
        up: up,
        maxHeight: maxHeight,
        options: widget.options,
        selected: _selectedIndex,
        active: _active,
        onClose: () {
          _close();
          _focus.requestFocus();
        },
        onPick: (v) {
          _close();
          widget.onChanged(v);
          _focus.requestFocus();
        },
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (!_open) {
      if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.arrowDown) {
        _show();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final last = widget.options.length - 1;
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.tab) {
      _close();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _active.value = (_active.value + 1).clamp(0, last);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _active.value = (_active.value - 1).clamp(0, last);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      final v = widget.options[_active.value].$1;
      _close();
      widget.onChanged(v);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final idx = _selectedIndex;
    final text = idx >= 0 ? widget.options[idx].$2 : (widget.placeholder ?? '');
    final placeholder = idx < 0 || widget.value == null || widget.value == '';
    return CrField(
      label: widget.label,
      error: widget.error,
      child: CompositedTransformTarget(
        link: _link,
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: KeyedSubtree(
              key: _faceKey,
              child: Semantics(
                button: true,
                label: '${widget.label}: $text',
                child: FieldFace(
                  focused: _open || _focus.hasFocus,
                  hovered: _hover,
                  invalid: widget.error != null,
                  onTap: () {
                    _focus.requestFocus();
                    _open ? _close() : _show();
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Text(
                            text.isEmpty ? ' ' : text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontFamilyFallback: fontFallback,
                              fontSize: 15,
                              height: 22 / 15,
                              fontWeight: FontWeight.w500,
                              color: placeholder ? c.inkMuted : c.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: space2),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: crEase,
                        child: CrIcon('chevron', size: 18, color: _open ? c.brand : c.inkMuted, stroke: 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectMenu<T> extends StatefulWidget {
  const _SelectMenu({
    required this.link,
    required this.width,
    required this.faceHeight,
    required this.up,
    required this.maxHeight,
    required this.options,
    required this.selected,
    required this.active,
    required this.onClose,
    required this.onPick,
  });
  final LayerLink link;
  final double width, faceHeight, maxHeight;
  final bool up;
  final List<(T, String)> options;
  final int selected;
  final ValueNotifier<int> active;
  final VoidCallback onClose;
  final ValueChanged<T> onPick;

  @override
  State<_SelectMenu<T>> createState() => _SelectMenuState<T>();
}

class _SelectMenuState<T> extends State<_SelectMenu<T>> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  final _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.value = 1;
    } else if (_c.status == AnimationStatus.dismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final curve = CurvedAnimation(parent: _c, curve: crPopEase);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: widget.onClose, child: const SizedBox.expand()),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          targetAnchor: widget.up ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: widget.up ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(0, widget.up ? -6 : 6),
          child: Align(
            alignment: widget.up ? Alignment.bottomLeft : Alignment.topLeft,
            child: SizedBox(
              width: widget.width,
              child: ExcludeFocus(
                child: AnimatedBuilder(
                  animation: curve,
                  builder: (context, child) => Opacity(
                    opacity: curve.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (widget.up ? 8 : -8) * (1 - curve.value)),
                      child: Transform.scale(
                        scale: 0.97 + 0.03 * curve.value,
                        alignment: widget.up ? Alignment.bottomCenter : Alignment.topCenter,
                        child: child,
                      ),
                    ),
                  ),
                  child: Container(
                    constraints: BoxConstraints(maxHeight: widget.maxHeight),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(radiusMd), boxShadow: [c.shadowLift]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radiusMd),
                      child: BackdropFilter(
                        filter: glassFilter(blurLg, 1.8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.glassStrong,
                            borderRadius: BorderRadius.circular(radiusMd),
                            border: Border.all(color: c.glassBorder),
                          ),
                          padding: const EdgeInsets.all(space2),
                          child: ValueListenableBuilder<int>(
                            valueListenable: widget.active,
                            builder: (context, _, _) => ListView.builder(
                              controller: _scroll,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: widget.options.length,
                              itemBuilder: (context, i) => _MenuItem(
                                label: widget.options[i].$2,
                                selected: i == widget.selected,
                                active: i == widget.active.value,
                                delay: Duration(milliseconds: 18 * (i > 8 ? 8 : i)),
                                onHover: () => widget.active.value = i,
                                onTap: () => widget.onPick(widget.options[i].$1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.selected,
    required this.active,
    required this.delay,
    required this.onHover,
    required this.onTap,
  });
  final String label;
  final bool selected, active;
  final Duration delay;
  final VoidCallback onHover, onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Rise(
      delay: delay,
      dy: -4,
      duration: const Duration(milliseconds: 280),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (_) => onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(active && !context.reduceMotion ? 2 : 0, 0, 0),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: space3),
            decoration: BoxDecoration(color: active ? c.brandSoft : Colors.transparent, borderRadius: BorderRadius.circular(radiusSm)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.isEmpty ? ' ' : label,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFallback,
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? c.brand : c.ink,
                    ),
                  ),
                ),
                if (selected) CrIcon('check', size: 18, color: c.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fecha (ISO `YYYY-MM-DD`) con calendario.
class CrDateField extends StatelessWidget {
  const CrDateField({super.key, required this.label, required this.value, required this.onChanged, this.error, this.optional = false});
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? error;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final date = (value == null || value!.isEmpty) ? null : DateTime.tryParse(value!);
    return CrField(
      label: label,
      error: error,
      child: FieldFace(
        invalid: error != null,
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? now,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            locale: const Locale('es', 'CO'),
          );
          if (picked != null) {
            onChanged(DateFormat('yyyy-MM-dd').format(picked));
          }
        },
        trail: optional && date != null
            ? _IconToggle(icon: 'trash', color: c.inkMuted, onTap: () => onChanged(null))
            : Padding(
                padding: const EdgeInsets.only(right: space2),
                child: CrIcon('calendar', size: 18, color: c.inkMuted),
              ),
        right: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            date == null ? 'dd/mm/aaaa' : DateFormat('dd/MM/yyyy').format(date),
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: fontFallback,
              fontSize: 15,
              height: 22 / 15,
              fontWeight: FontWeight.w500,
              color: date == null ? c.inkMuted : c.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector de mes (`<input type="month">`): año con flechas y cuadrícula de meses.
class CrMonthField extends StatelessWidget {
  const CrMonthField({super.key, required this.label, required this.month, required this.onChanged});
  final String label;
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CrField(
      label: label,
      child: FieldFace(
        onTap: () async {
          final picked = await showCrDialog<DateTime>(context, builder: (_) => _MonthPicker(initial: month));
          if (picked != null) onChanged(picked);
        },
        right: 48,
        trail: Padding(
          padding: const EdgeInsets.only(right: space2),
          child: CrIcon('calendar', size: 18, color: c.inkMuted),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            DateFormat("MMMM 'de' y", 'es').format(month),
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: fontFallback,
              fontSize: 15,
              height: 22 / 15,
              fontWeight: FontWeight.w500,
              color: c.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initial});
  final DateTime initial;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Transform.rotate(angle: 3.14159, child: _arrow(() => setState(() => _year--), 'Año anterior')),
            Expanded(
              child: Center(child: Text('$_year', style: CrText.heading(c.ink))),
            ),
            _arrow(() => setState(() => _year++), 'Año siguiente'),
          ],
        ),
        const SizedBox(height: space3),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: space2,
          crossAxisSpacing: space2,
          childAspectRatio: 2.2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var m = 1; m <= 12; m++)
              GestureDetector(
                onTap: () => Navigator.pop(context, DateTime(_year, m)),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (widget.initial.year == _year && widget.initial.month == m) ? c.brandSoft : c.glass,
                    borderRadius: BorderRadius.circular(radiusSm),
                    border: Border.all(color: (widget.initial.year == _year && widget.initial.month == m) ? c.brand : c.glassBorder),
                  ),
                  child: Text(
                    toBeginningOfSentenceCase(DateFormat.MMM('es').format(DateTime(2000, m)).replaceAll('.', ''))!,
                    style: CrText.label(c.ink),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _arrow(VoidCallback onTap, String label) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: CrIcon('arrow', size: 18, color: context.c.inkMuted)),
      ),
    ),
  );
}
