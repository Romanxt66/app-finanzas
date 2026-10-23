import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_drawing/path_drawing.dart';

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
    final titleSize = (width * 0.08).clamp(30.0, 52.0);
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
                  fontSize: 20,
                  height: 24 / 20,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: space4),
        Rise(
          delay: const Duration(milliseconds: 80),
          duration: const Duration(milliseconds: 600),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: titleSize * 11),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Tu dinero, '),
                  TextSpan(
                    text: 'claro',
                    style: TextStyle(
                      foreground: Paint()
                        ..shader = LinearGradient(colors: [c.brand, const Color(0xFFE879F9)])
                            .createShader(Rect.fromLTWH(0, 0, titleSize * 3, titleSize)),
                    ),
                  ),
                  const TextSpan(text: ' como el cristal.'),
                ],
              ),
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
                fontSize: titleSize,
                height: 1.06,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.025 * titleSize,
                color: c.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: space4),
        Rise(
          delay: const Duration(milliseconds: 160),
          duration: const Duration(milliseconds: 600),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 28 * 15.0),
            child: Text(
              'Saldo, gastos y metas en un solo lugar. Entra para ver cómo va tu mes.',
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallback,
                fontSize: 15,
                height: 24 / 15,
                fontWeight: FontWeight.w500,
                color: c.inkMuted,
              ),
            ),
          ),
        ),
        if (wide) ...[
          const SizedBox(height: space5),
          Rise(delay: const Duration(milliseconds: 240), duration: const Duration(milliseconds: 600), child: const _HeroArt()),
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
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 24,
                    height: 30 / 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.01 * 24,
                    color: c.ink,
                  ),
                ),
              ),
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

/// Adorno de la columna izquierda: formas de vidrio flotantes sin cifras reales.
class _HeroArt extends StatefulWidget {
  const _HeroArt();

  @override
  State<_HeroArt> createState() => _HeroArtState();
}

class _HeroArtState extends State<_HeroArt> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  late final AnimationController _b = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  late final AnimationController _shimmer = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _draw.value = 1;
    } else {
      _a.repeat(reverse: true);
      _b.repeat(reverse: true);
      _shimmer.repeat();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _draw.forward();
      });
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _shimmer.dispose();
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 8,
              child: AnimatedBuilder(
                animation: _a,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_a.value);
                  return Transform.translate(
                    offset: Offset(0, -8 * t),
                    child: Transform.rotate(angle: (-4 + t) * math.pi / 180, child: child),
                  );
                },
                child: SizedBox(
                  width: 250,
                  child: Glass(
                    radius: radiusMd,
                    padding: const EdgeInsets.all(space4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo total',
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontFamilyFallback: fontFallback,
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w500,
                            color: c.inkMuted,
                          ),
                        ),
                        const SizedBox(height: space2),
                        AnimatedBuilder(
                          animation: _shimmer,
                          builder: (context, _) => Container(
                            width: 250 * 0.7 - 12,
                            height: 22,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(radiusPill),
                              gradient: LinearGradient(
                                begin: Alignment(-3 + 6 * _shimmer.value, 0),
                                end: Alignment(-1 + 6 * _shimmer.value, 0),
                                colors: [c.brandSoft, c.glassStrong, c.brandSoft],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: space2),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: AnimatedBuilder(
                            animation: _draw,
                            builder: (context, _) => CustomPaint(painter: _SparkDraw(_draw.value, c.brand)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 150,
              top: 118,
              child: AnimatedBuilder(
                animation: _b,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_b.value);
                  return Transform.translate(
                    offset: Offset(0, 7 * t),
                    child: Transform.rotate(angle: (3 - t) * math.pi / 180, child: child),
                  );
                },
                child: Glass(
                  radius: radiusMd,
                  padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CrChip('shield', tone: Tone.brand),
                      const SizedBox(width: space3),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sesión protegida',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontFamilyFallback: fontFallback,
                              fontSize: 13,
                              height: 18 / 13,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            'Tus datos son solo tuyos',
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontFamilyFallback: fontFallback,
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w500,
                              color: c.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkDraw extends CustomPainter {
  _SparkDraw(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = parseSvgPathData('M2 26 C18 24 22 12 38 15 S62 28 78 14 S104 6 118 4');
    canvas.translate((size.width - 120) / 2, 0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * Curves.ease.transform(t)), paint);
    }
  }

  @override
  bool shouldRepaint(_SparkDraw old) => old.t != t;
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
              child: Text(
                'o entra con',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontFamilyFallback: fontFallback,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: c.inkMuted,
                ),
              ),
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
