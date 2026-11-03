import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/biometric.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/glass.dart';
import '../ui/mood_face.dart';
import '../ui/theme.dart';

/// Muestra la [LockScreen] encima de la app mientras esté bloqueada. La app sigue montada debajo
/// (no pierde lo que se estaba escribiendo), pero oculta e inerte.
class LockGate extends StatelessWidget {
  const LockGate({super.key, required this.state, required this.child});
  final AppState state;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state.lock,
    child: child,
    builder: (context, app) {
      final locked = state.lock.locked && state.user != null;
      // expand: con la app oculta, el Stack no puede medir 0×0 (la pantalla de bloqueo no se vería)
      return Stack(
        fit: StackFit.expand,
        children: [
          Visibility(visible: !locked, maintainState: true, child: app!),
          // Overlay propio: la pantalla está por encima del Navigator y sus botones tienen tooltips
          if (locked) Overlay.wrap(child: const LockScreen()),
        ],
      );
    },
  );
}

/// Pantalla de bloqueo: pide el PIN de este dispositivo para volver a la app.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _face = GlobalKey<MoodFaceState>();
  final _focus = FocusNode();
  String _pin = '';
  bool _wrong = false;

  /// La huella está activada y el dispositivo la admite (solo app nativa).
  bool _biometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      if (context.app.lock.useBiometrics) {
        biometricAvailable().then((ok) {
          if (!mounted || !ok) return;
          setState(() => _biometric = true);
          _useBiometric(); // se ofrece directamente al abrir; si se cancela queda el teclado
        });
      }
    });
  }

  Future<void> _useBiometric() async {
    final lock = context.app.lock;
    final ok = await lock.whileAway(() => authenticateBiometric('Desbloquea Alvea'));
    if (ok && mounted) lock.unlockWithBiometrics();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _type(String digit) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _wrong = false;
    });
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (_pin.length < 4) return;
    final ok = context.app.lock.unlock(_pin);
    if (!ok) {
      _face.currentState?.boing();
      setState(() {
        _pin = '';
        _wrong = true;
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _type(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    final lock = app.lock;
    final left = lock.attemptsLeft;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(space4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Glass(
                  strong: true,
                  padding: const EdgeInsets.all(space5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoodFace(key: _face, expression: _wrong ? _worried : _calm, size: 96),
                      const SizedBox(height: space3),
                      Semantics(
                        header: true,
                        child: Text('Alvea está bloqueada', style: CrText.heading(c.ink), textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: space1),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _wrong
                              ? 'PIN incorrecto. Te quedan $left ${left == 1 ? 'intento' : 'intentos'}.'
                              : 'Escribe tu PIN para continuar${app.user != null ? ', ${app.user!.fullName.split(' ').first}' : ''}.',
                          textAlign: TextAlign.center,
                          style: CrText.body(_wrong ? c.negative : c.inkMuted),
                        ),
                      ),
                      const SizedBox(height: space4),
                      Semantics(
                        label: 'PIN: ${_pin.length} de 4 a 6 dígitos',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 6; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i < _pin.length ? c.neon : Colors.transparent,
                                  border: Border.all(color: i < 4 ? c.inkMuted : c.inkFaint, width: 1.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: space4),
                      _Keypad(onDigit: _type, onBack: _back, onSubmit: _pin.length >= 4 ? _submit : null),
                      if (_biometric) ...[
                        const SizedBox(height: space3),
                        CrButton(icon: 'fingerprint', label: 'Usar huella', onPressed: _useBiometric),
                      ],
                      const SizedBox(height: space3),
                      CrButton(
                        variant: CrButtonVariant.ghost,
                        small: true,
                        label: '¿Olvidaste el PIN? Cerrar sesión',
                        onPressed: () => app.logout(),
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

const _calm = FaceExpression(color: Color(0xFFF0ABFC), smile: 0.4, eyeHappy: 0.85, blush: 0.4);
const _worried = FaceExpression(color: Color(0xFFFB923C), smile: -0.45, brow: 1, browShow: 1, sweat: 0.9);

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBack, required this.onSubmit});
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback? onTap, {String? tooltip, String? icon}) => SizedBox(
      width: 72,
      height: 56,
      child: CrButton(
        variant: CrButtonVariant.glass,
        label: icon == null ? label : null,
        icon: icon,
        tooltip: tooltip,
        onPressed: onTap,
        height: 56,
        expand: true,
      ),
    );
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: space2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final d in r) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: key(d, () => onDigit(d)))],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: key('', onBack, tooltip: 'Borrar', icon: 'backspace'),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: key('0', () => onDigit('0'))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: key('OK', onSubmit, tooltip: 'Desbloquear', icon: 'check'),
            ),
          ],
        ),
      ],
    );
  }
}
