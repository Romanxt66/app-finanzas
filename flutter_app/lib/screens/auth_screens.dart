import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/password.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/glass.dart';
import '../ui/inputs.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'layout.dart' show BrandMark;

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Requisitos de contraseña que se marcan a medida que se escribe.
class PasswordRules extends StatelessWidget {
  const PasswordRules(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Requisitos de la contraseña',
      child: Wrap(
        spacing: space4,
        runSpacing: space1,
        children: [
          for (final r in passwordRules)
            Builder(
              builder: (context) {
                final ok = value.isNotEmpty && r.ok(value);
                return Text(
                  '${ok ? '✓' : '○'} ${r.label}',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w500,
                    color: ok ? c.positive : c.inkMuted,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Estructura de las pantallas de acceso: héroe a la izquierda, tarjeta de cristal a la derecha.
class _AuthShell extends StatelessWidget {
  const _AuthShell({required this.title, required this.subtitle, required this.children, required this.footer});
  final String title, subtitle;
  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = context.isWide;
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = (width * 0.085).clamp(34.0, 60.0);
    final hero = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Rise(
          duration: const Duration(milliseconds: 600),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(),
              const SizedBox(width: space2),
              Text(
                'Alvea',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontFamilyFallback: fontFallback,
                  fontSize: 19,
                  height: 24 / 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: space4),
        const SizedBox(height: space2),
        Rise(
          delay: const Duration(milliseconds: 60),
          duration: const Duration(milliseconds: 600),
          child: const CrTag('acceso seguro / tus datos, solo tuyos', pulse: true),
        ),
        const SizedBox(height: space5),
        Rise(
          delay: const Duration(milliseconds: 120),
          duration: const Duration(milliseconds: 700),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: titleSize * 11),
            child: CrHeadline('Tu dinero, *claro* como el cristal.', size: titleSize, accentColor: c.brand),
          ),
        ),
        const SizedBox(height: space4),
        Rise(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 600),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 28 * 15.0),
            child: Text(
              'Saldo, gastos y metas en un solo lugar. Entra para ver cómo va tu mes.',
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
                fontSize: 16,
                height: 26 / 16,
                fontWeight: FontWeight.w500,
                color: c.inkMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: space4),
        Rise(
          delay: const Duration(milliseconds: 260),
          duration: const Duration(milliseconds: 600),
          child: Text('gratis / sin anuncios / sin letra pequeña', style: CrText.mono(c.inkFaint, size: 12)),
        ),
        if (wide) ...[
          const SizedBox(height: space5),
          const SizedBox(height: space3),
          Rise(delay: const Duration(milliseconds: 320), duration: const Duration(milliseconds: 800), child: const _FlowPanel()),
        ],
      ],
    );
    final card = Rise(
      duration: const Duration(milliseconds: 600),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Glass(
          strong: true,
          padding: wide
              ? const EdgeInsets.symmetric(horizontal: 32, vertical: 36)
              : const EdgeInsets.symmetric(horizontal: space5, vertical: space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(header: true, child: Text(title, style: CrText.display(c.ink, size: 28))),
              const SizedBox(height: space3),
              Padding(
                padding: const EdgeInsets.only(bottom: space2),
                child: Text(
                  subtitle,
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
              for (final w in children) ...[w, const SizedBox(height: space3)],
              footer,
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: space5, vertical: space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 11, child: hero),
                        const SizedBox(width: space6),
                        SizedBox(width: 440, child: card),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        hero,
                        const SizedBox(height: space6),
                        Center(child: card),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adorno de la columna izquierda: un panel «consola» inclinado en perspectiva con el flujo de
/// tu dinero (nodos y conexiones con pulsos de luz). Decorativo y sin cifras.
class _FlowPanel extends StatefulWidget {
  const _FlowPanel();

  @override
  State<_FlowPanel> createState() => _FlowPanelState();
}

class _FlowPanelState extends State<_FlowPanel> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!context.reduceMotion) {
      _float.repeat(reverse: true);
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _pulse.dispose();
    super.dispose();
  }

  static const _w = 600.0;
  static const _h = 330.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget node(String title, String sub, {bool active = false}) => Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? c.neon.withValues(alpha: 0.6) : c.glassBorder),
        boxShadow: active ? [BoxShadow(color: c.neonGlow, blurRadius: 18)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: CrText.label(c.ink).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, style: CrText.mono(c.inkFaint, size: 10.5)),
        ],
      ),
    );
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.glassBorder),
      ),
      child: Text(text, style: CrText.mono(c.inkMuted, size: 10)),
    );
    Widget event(String what, String when) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: c.neon, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(what, style: CrText.mono(c.inkMuted, size: 11))),
          Text(when, style: CrText.mono(c.inkFaint, size: 11)),
        ],
      ),
    );

    final panel = SizedBox(
      width: _w,
      height: _h,
      child: Container(
        decoration: BoxDecoration(
          color: c.panel.withValues(alpha: c.isDark ? 0.78 : 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.glassBorder),
          boxShadow: [c.shadowLift],
        ),
        child: Stack(
          children: [
            // Cabecera del panel
            Positioned(
              left: 20,
              right: 20,
              top: 16,
              child: Row(
                children: [
                  Text('tu mes', style: CrText.mono(c.inkMuted, size: 11.5)),
                  Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 10), color: c.hairline),
                  Text('3 pasos / 1 rama', style: CrText.mono(c.ink, size: 11.5)),
                  const Spacer(),
                  Text('en vivo', style: CrText.mono(c.neon, size: 11.5)),
                ],
              ),
            ),
            // Conexiones con pulsos de luz
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(painter: _FlowLinesPainter(_pulse.value, c.neon, c.glassHighlight)),
              ),
            ),
            Positioned(left: 20, top: 120, child: node('Ingreso registrado', 'nómina', active: true)),
            Positioned(left: 220, top: 62, child: node('¿Supera el presupuesto?', 'condición')),
            Positioned(left: 220, top: 172, child: node('Aparta al ahorro', 'meta de ahorro')),
            Positioned(left: 172, top: 92, child: chip('sí')),
            Positioned(left: 172, top: 188, child: chip('no')),
            Positioned(right: 18, top: 117, child: node('Disponible hoy', 'se recalcula')),
            // Últimos eventos
            Positioned(
              left: 20,
              right: 20,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('últimos eventos', style: CrText.mono(c.inkFaint, size: 10.5)),
                  const SizedBox(height: 8),
                  event('suscripción detectada', 'hace 2 min'),
                  event('presupuesto de ocio al 80 %', 'hoy'),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = math.min(1.0, box.maxWidth / (_w + 40));
          return SizedBox(
            height: _h * scale + 30,
            child: AnimatedBuilder(
              animation: _float,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_float.value);
                return Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0011)
                    ..rotateY(-0.30 + 0.04 * t)
                    ..rotateX(0.06)
                    ..translateByDouble(0, -6 * t, 0, 1),
                  child: child,
                );
              },
              child: Align(
                alignment: Alignment.topLeft,
                child: Transform.scale(scale: scale, alignment: Alignment.topLeft, child: panel),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Curvas entre nodos del panel; un punto de luz recorre cada una.
class _FlowLinesPainter extends CustomPainter {
  _FlowLinesPainter(this.t, this.neon, this.line);
  final double t;
  final Color neon, line;

  @override
  void paint(Canvas canvas, Size size) {
    Path curve(Offset a, Offset b) => Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + (b.dx - a.dx) * 0.5, a.dy, a.dx + (b.dx - a.dx) * 0.5, b.dy, b.dx, b.dy);
    final right = size.width - 18 - 140;
    const out = Offset(160, 143);
    const midTop = Offset(220, 89), midBot = Offset(220, 199);
    const midTopOut = Offset(360, 89), midBotOut = Offset(360, 199);
    final target = Offset(right, 140);
    final paths = [curve(out, midTop), curve(out, midBot), curve(midTopOut, target), curve(midBotOut, target)];
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = neon.withValues(alpha: 0.45);
    for (var i = 0; i < paths.length; i++) {
      canvas.drawPath(paths[i], stroke);
      for (final m in paths[i].computeMetrics()) {
        final phase = (t + i * 0.22) % 1.0;
        final pos = m.getTangentForOffset(m.length * phase)?.position;
        if (pos == null) continue;
        canvas.drawCircle(
          pos,
          6,
          Paint()
            ..color = neon.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(pos, 2.2, Paint()..color = Colors.white);
      }
    }
    // Puntos de anclaje
    for (final p in [out, midTop, midBot, midTopOut, midBotOut, target]) {
      canvas.drawCircle(p, 2.5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_FlowLinesPainter old) => old.t != t || old.neon != neon;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _busy = false;
  bool _submitted = false;
  Object? _error;

  String? get _emailError => _submitted && !_emailRe.hasMatch(_email.text.trim()) ? 'Correo inválido' : null;
  String? get _passwordError => _submitted && _password.text.isEmpty ? 'Requerida' : null;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_emailError != null || _passwordError != null || _busy) return;
    final app = context.app;
    setState(() => _busy = true);
    try {
      await app.login(_email.text.trim(), _password.text, remember: _remember);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _AuthShell(
      title: 'Iniciar sesión',
      subtitle: 'Bienvenido de nuevo. Ingresa tus datos para continuar.',
      footer: _FootLink(prefix: '¿Aún no tienes cuenta? ', link: 'Regístrate gratis', onTap: () => context.go('/register')),
      children: [
        CrTextField(
          label: 'Correo',
          controller: _email,
          icon: 'mail',
          hint: 'nombre@correo.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          error: _emailError,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.next,
        ),
        CrPasswordField(
          label: 'Contraseña',
          controller: _password,
          error: _passwordError,
          autofillHints: const [AutofillHints.password],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: CrCheckbox(value: _remember, onChanged: (v) => setState(() => _remember = v), label: 'Mantener sesión iniciada'),
        ),
        ErrorText(_error),
        CrButton(
          variant: CrButtonVariant.primary,
          label: 'Entrar',
          trailingIcon: 'arrow',
          expand: true,
          height: 48,
          onPressed: _busy ? null : _submit,
        ),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: c.hairline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: space3),
              child: Text('o entra con', style: CrText.mono(c.inkFaint, size: 11.5)),
            ),
            Expanded(child: Container(height: 1, color: c.hairline)),
          ],
        ),
        const Row(
          children: [
            Expanded(
              child: CrButton(icon: 'fingerprint', label: 'Huella', tooltip: 'Huella (próximamente)', expand: true),
            ),
            SizedBox(width: space3),
            Expanded(
              child: CrButton(icon: 'key', label: 'Passkey', tooltip: 'Passkey (próximamente)', expand: true),
            ),
          ],
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  Object? _error;

  String? get _nameError => _submitted && (_name.text.trim().isEmpty ? true : _name.text.trim().length > 120)
      ? (_name.text.trim().isEmpty ? 'Requerido' : 'Máximo 120 caracteres')
      : null;
  String? get _emailError => _submitted && !_emailRe.hasMatch(_email.text.trim()) ? 'Correo inválido' : null;
  String? get _passwordError => _submitted ? passwordProblem(_password.text) : null;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null || _emailError != null || _passwordError != null || _busy) {
      return;
    }
    final app = context.app;
    setState(() => _busy = true);
    try {
      await app.register(_name.text.trim(), _email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
    title: 'Crear cuenta',
    subtitle: 'Empieza a ver tu dinero con claridad.',
    footer: _FootLink(prefix: '¿Ya tienes cuenta? ', link: 'Inicia sesión', onTap: () => context.go('/login')),
    children: [
      CrTextField(
        label: 'Nombre',
        controller: _name,
        icon: 'user',
        autofillHints: const [AutofillHints.name],
        error: _nameError,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.next,
      ),
      CrTextField(
        label: 'Correo',
        controller: _email,
        icon: 'mail',
        hint: 'nombre@correo.com',
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        error: _emailError,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.next,
      ),
      CrPasswordField(
        label: 'Contraseña',
        controller: _password,
        error: _passwordError,
        autofillHints: const [AutofillHints.newPassword],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      PasswordRules(_password.text),
      ErrorText(_error),
      CrButton(
        variant: CrButtonVariant.primary,
        label: 'Crear cuenta',
        trailingIcon: 'arrow',
        expand: true,
        height: 48,
        onPressed: _busy ? null : _submit,
      ),
    ],
  );
}

class _FootLink extends StatelessWidget {
  const _FootLink({required this.prefix, required this.link, required this.onTap});
  final String prefix, link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      color: c.inkMuted,
    );
    return Center(
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: prefix),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onTap,
                  child: Text(
                    link,
                    style: base.copyWith(color: c.brand, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
