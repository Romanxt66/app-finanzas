import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_lock.dart';
import '../core/biometric.dart';
import '../core/notices.dart';
import '../core/state.dart';
import '../ui/buttons.dart';
import '../ui/dialogs.dart';
import '../ui/download.dart';
import '../ui/inputs.dart';
import '../ui/page.dart';
import '../ui/qr_view.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Tarjeta «Seguridad» del perfil: verificación en dos pasos, bloqueo con PIN y avisos del navegador.
class SecurityCard extends StatelessWidget {
  const SecurityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final twoFactor = app.user?.twoFactor ?? false;
    return CrCard(
      title: 'Seguridad',
      child: ListenableBuilder(
        listenable: Listenable.merge([app.lock, app.notices]),
        builder: (context, _) {
          final lock = app.lock;
          final permission = NoticeCenter.browserPermission;
          return Stack12(
            children: [
              _Option(
                icon: 'shield',
                title: 'Verificación en dos pasos',
                status: twoFactor ? 'Activada' : 'Desactivada',
                on: twoFactor,
                body:
                    'Al entrar, además de la contraseña te pediremos un código de tu app de autenticación '
                    '(Google Authenticator, Microsoft Authenticator, 1Password…).',
                actions: [
                  if (!twoFactor)
                    CrButton(
                      variant: CrButtonVariant.primary,
                      small: true,
                      label: 'Activar',
                      onPressed: () => showCrDialog<void>(
                        context,
                        title: 'Activar verificación en dos pasos',
                        maxWidth: 440,
                        builder: (_) => const _TwoFactorSetup(),
                      ),
                    )
                  else ...[
                    CrButton(
                      small: true,
                      label: 'Nuevos códigos de recuperación',
                      onPressed: () => showCrDialog<void>(
                        context,
                        title: 'Códigos de recuperación',
                        maxWidth: 440,
                        builder: (_) => const _RegenerateCodes(),
                      ),
                    ),
                    CrButton(
                      variant: CrButtonVariant.danger,
                      small: true,
                      label: 'Desactivar',
                      onPressed: () => showCrDialog<void>(
                        context,
                        title: 'Desactivar verificación en dos pasos',
                        builder: (_) => const _TwoFactorDisable(),
                      ),
                    ),
                  ],
                ],
              ),
              Container(height: 1, color: c.hairline),
              _Option(
                icon: 'lock',
                title: 'Bloqueo con PIN',
                status: lock.enabled ? 'Activado' : 'Desactivado',
                on: lock.enabled,
                body:
                    'Pide un PIN de 4 a 6 dígitos al abrir Alvea en este dispositivo. '
                    'Tras ${AppLock.maxAttempts} intentos fallidos se cierra la sesión.',
                actions: [
                  CrButton(
                    variant: lock.enabled ? CrButtonVariant.glass : CrButtonVariant.primary,
                    small: true,
                    label: lock.enabled ? 'Cambiar PIN' : 'Crear PIN',
                    onPressed: () =>
                        showCrDialog<void>(context, title: lock.enabled ? 'Cambiar PIN' : 'Crear PIN', builder: (_) => const _PinForm()),
                  ),
                  if (lock.enabled)
                    CrButton(
                      variant: CrButtonVariant.danger,
                      small: true,
                      label: 'Quitar PIN',
                      onPressed: () => showCrDialog<void>(context, title: 'Quitar PIN', builder: (_) => const _PinForm(remove: true)),
                    ),
                ],
                footer: lock.enabled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: space3,
                            runSpacing: space2,
                            children: [
                              Text('Volver a pedirlo tras', style: CrText.label(c.inkMuted)),
                              CrSegmented<Duration>(
                                options: const [
                                  (Duration.zero, 'Al salir'),
                                  (Duration(minutes: 1), '1 min'),
                                  (Duration(minutes: 5), '5 min'),
                                  (Duration(minutes: 15), '15 min'),
                                ],
                                value: lock.delay,
                                onChanged: lock.setDelay,
                              ),
                            ],
                          ),
                        ],
                      )
                    : null,
              ),
              if (!kIsWeb) const _BiometricOption(),
              // En la app de Android los avisos del sistema se ajustan en «Recordatorios de cobro»
              if (kIsWeb) ...[
                Container(height: 1, color: c.hairline),
                _Option(
                  icon: 'bell',
                  title: 'Avisos del navegador',
                  status: app.notices.browserAlerts && permission == 'granted' ? 'Activados' : 'Desactivados',
                  on: app.notices.browserAlerts && permission == 'granted',
                  body: permission == 'unsupported'
                      ? 'Este navegador no permite avisos. Los verás en la campana de la barra superior.'
                      : permission == 'denied'
                      ? 'Bloqueaste los avisos de Alvea en el navegador. Actívalos en la configuración del sitio (icono del candado).'
                      : 'Un aviso del sistema cuando se acerque un cobro o te pases de un presupuesto (con Alvea abierta).',
                  actions: [
                    if (permission != 'unsupported' && permission != 'denied')
                      CrButton(
                        small: true,
                        label: app.notices.browserAlerts ? 'Desactivar' : 'Activar',
                        onPressed: () async {
                          final on = await app.notices.setBrowserAlerts(!app.notices.browserAlerts);
                          if (!on && !app.notices.browserAlerts && NoticeCenter.browserPermission == 'denied') {
                            app.onToast?.call('El navegador bloqueó los avisos');
                          }
                        },
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Abrir Alvea con la huella o el rostro (app nativa con biometría disponible). El PIN queda de
/// respaldo: si aún no hay, se crea primero y la huella se activa al terminar.
class _BiometricOption extends StatefulWidget {
  const _BiometricOption();

  @override
  State<_BiometricOption> createState() => _BiometricOptionState();
}

class _BiometricOptionState extends State<_BiometricOption> {
  late final Future<bool> _available = biometricAvailable();

  Future<void> _toggle(bool value) async {
    final app = context.app;
    final lock = app.lock;
    if (value && !lock.enabled) {
      await showCrDialog<void>(context, title: 'PIN de respaldo', builder: (_) => const _PinForm(thenBiometric: true));
      return;
    }
    if (value && !await enableBiometrics(lock)) return;
    if (!value) await lock.setUseBiometrics(false);
    app.onToast?.call(value ? 'Podrás abrir Alvea con tu huella' : 'Alvea pedirá solo el PIN');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _available,
    builder: (context, snap) {
      if (snap.data != true) return const SizedBox.shrink();
      final c = context.c;
      final lock = context.app.lock;
      final on = lock.useBiometrics;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: c.hairline),
          const SizedBox(height: space3),
          _Option(
            icon: 'fingerprint',
            title: 'Huella o rostro',
            status: on ? 'Activado' : 'Desactivado',
            on: on,
            body: lock.enabled
                ? 'Abre Alvea con la huella, el rostro o el bloqueo del teléfono. El PIN sigue sirviendo si la huella falla.'
                : 'Abre Alvea con la huella, el rostro o el bloqueo del teléfono. Primero crearás un PIN de respaldo por si la huella falla.',
            actions: [
              CrButton(
                variant: on ? CrButtonVariant.glass : CrButtonVariant.primary,
                small: true,
                icon: on ? null : 'fingerprint',
                label: on ? 'Desactivar' : 'Activar huella',
                onPressed: () => _toggle(!on),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Confirma la huella una vez (así se sabe que funciona en este teléfono) y la activa.
Future<bool> enableBiometrics(AppLock lock) async {
  final ok = await lock.whileAway(() => authenticateBiometric('Confirma para abrir Alvea con tu huella'));
  if (ok) await lock.setUseBiometrics(true);
  return ok;
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.status,
    required this.on,
    required this.body,
    required this.actions,
    this.footer,
  });
  final String icon, title, status, body;
  final bool on;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: space2,
          runSpacing: space1,
          children: [
            Text(title, style: CrText.body(c.ink).copyWith(fontWeight: FontWeight.w700)),
            CrBadge(status, tone: on ? Tone.positive : Tone.neutral, icon: on ? 'check' : null),
          ],
        ),
        const SizedBox(height: space1),
        Text(body, style: CrText.caption(c.inkMuted)),
        if (actions.isNotEmpty) ...[const SizedBox(height: space3), Wrap(spacing: space2, runSpacing: space2, children: actions)],
        if (footer != null) ...[const SizedBox(height: space3), footer!],
      ],
    );
  }
}

/// Muestra los códigos de recuperación con opciones para copiarlos o descargarlos.
class _RecoveryCodes extends StatelessWidget {
  const _RecoveryCodes(this.codes);
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    final text = codes.join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Guárdalos en un lugar seguro. Cada uno sirve una sola vez para entrar si pierdes el móvil. '
          'No los volverás a ver.',
          style: CrText.caption(c.inkMuted),
        ),
        const SizedBox(height: space3),
        Container(
          padding: const EdgeInsets.all(space3),
          decoration: BoxDecoration(
            color: c.panel.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.glassBorder),
          ),
          child: SelectionArea(
            child: Wrap(
              spacing: space4,
              runSpacing: space2,
              children: [for (final code in codes) Text(code, style: CrText.mono(c.ink, size: 14))],
            ),
          ),
        ),
        const SizedBox(height: space3),
        Wrap(
          spacing: space2,
          runSpacing: space2,
          children: [
            CrButton(
              small: true,
              label: 'Copiar',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                app.onToast?.call('Códigos copiados');
              },
            ),
            CrButton(
              small: true,
              icon: 'download',
              label: 'Descargar',
              onPressed: () => app.lock.whileAway(
                () => saveFile(
                  utf8.encode('Códigos de recuperación de Alvea (${app.user?.email ?? ''})\n\n$text\n'),
                  'alvea-codigos-recuperacion.txt',
                  mime: 'text/plain',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TwoFactorSetup extends StatefulWidget {
  const _TwoFactorSetup();

  @override
  State<_TwoFactorSetup> createState() => _TwoFactorSetupState();
}

class _TwoFactorSetupState extends State<_TwoFactorSetup> {
  final _code = TextEditingController();
  ({String secret, String uri})? _setup;
  List<String>? _codes;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final res = await context.app.api.post('/auth/2fa/setup') as Map<String, dynamic>;
      if (mounted) setState(() => _setup = (secret: res['secret'] as String, uri: res['otpauth_uri'] as String));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.replaceAll(RegExp(r'\s'), '');
    if (code.length != 6 || _busy) {
      setState(() => _error = 'Escribe los 6 dígitos que muestra la app');
      return;
    }
    final app = context.app;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await app.api.post('/auth/2fa/enable', body: {'code': code}) as Map<String, dynamic>;
      await app.reloadUser();
      if (mounted) setState(() => _codes = [for (final c in res['recovery_codes'] as List<dynamic>) '$c']);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_codes != null) {
      return Stack12(
        children: [
          const CrBadge('Verificación en dos pasos activada', tone: Tone.positive, icon: 'check'),
          _RecoveryCodes(_codes!),
          CrButton(variant: CrButtonVariant.primary, label: 'Listo, los guardé', onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }
    final setup = _setup;
    if (setup == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (_error == null) Text('Preparando…', style: CrText.body(c.inkMuted)) else ErrorText(_error)],
      );
    }
    final grouped = [for (var i = 0; i < setup.secret.length; i += 4) setup.secret.substring(i, (i + 4).clamp(0, setup.secret.length))]
        .join(' ');
    return Stack12(
      children: [
        Text('1. Escanea el código con tu app de autenticación.', style: CrText.body(c.ink)),
        Center(child: QrView(setup.uri, size: 196, semanticLabel: 'Código QR para tu app de autenticación')),
        Text('¿No puedes escanearlo? Escribe esta clave en la app:', style: CrText.caption(c.inkMuted)),
        Row(
          children: [
            Expanded(child: SelectableText(grouped, style: CrText.mono(c.ink, size: 13))),
            CrButton(
              variant: CrButtonVariant.ghost,
              small: true,
              label: 'Copiar',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: setup.secret));
                if (context.mounted) context.app.onToast?.call('Clave copiada');
              },
            ),
          ],
        ),
        Text('2. Escribe el código de 6 dígitos que aparece.', style: CrText.body(c.ink)),
        CrTextField(
          label: 'Código',
          controller: _code,
          hint: '123 456',
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 7,
          autofocus: true,
          onSubmitted: (_) => _confirm(),
        ),
        ErrorText(_error),
        CrButton(variant: CrButtonVariant.primary, label: 'Activar', expand: true, onPressed: _busy ? null : _confirm),
      ],
    );
  }
}

class _TwoFactorDisable extends StatefulWidget {
  const _TwoFactorDisable();

  @override
  State<_TwoFactorDisable> createState() => _TwoFactorDisableState();
}

class _TwoFactorDisableState extends State<_TwoFactorDisable> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.app;
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.api.post('/auth/2fa/disable', body: {'password': _password.text, 'code': _code.text.trim()});
      await app.reloadUser();
      app.onToast?.call('Verificación en dos pasos desactivada');
      nav.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Stack12(
    children: [
      Text('Tu cuenta quedará protegida solo con la contraseña.', style: CrText.caption(context.c.inkMuted)),
      CrPasswordField(label: 'Contraseña', controller: _password, autofillHints: const [AutofillHints.password]),
      CrTextField(
        label: 'Código de la app o de recuperación',
        controller: _code,
        autofillHints: const [AutofillHints.oneTimeCode],
        onSubmitted: (_) => _submit(),
      ),
      ErrorText(_error),
      CrButton(variant: CrButtonVariant.danger, label: 'Desactivar', expand: true, onPressed: _busy ? null : _submit),
    ],
  );
}

class _RegenerateCodes extends StatefulWidget {
  const _RegenerateCodes();

  @override
  State<_RegenerateCodes> createState() => _RegenerateCodesState();
}

class _RegenerateCodesState extends State<_RegenerateCodes> {
  final _code = TextEditingController();
  List<String>? _codes;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await context.app.api.post('/auth/2fa/recovery-codes', body: {'code': _code.text.trim()}) as Map<String, dynamic>;
      if (mounted) setState(() => _codes = [for (final c in res['recovery_codes'] as List<dynamic>) '$c']);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_codes != null) {
      return Stack12(
        children: [
          _RecoveryCodes(_codes!),
          CrButton(variant: CrButtonVariant.primary, label: 'Listo', onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }
    return Stack12(
      children: [
        Text('Los códigos anteriores dejarán de servir.', style: CrText.caption(context.c.inkMuted)),
        CrTextField(
          label: 'Código de tu app de autenticación',
          controller: _code,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          autofocus: true,
          onSubmitted: (_) => _submit(),
        ),
        ErrorText(_error),
        CrButton(variant: CrButtonVariant.primary, label: 'Generar códigos nuevos', expand: true, onPressed: _busy ? null : _submit),
      ],
    );
  }
}

/// Crear, cambiar o quitar el PIN de este dispositivo.
class _PinForm extends StatefulWidget {
  const _PinForm({this.remove = false, this.thenBiometric = false});
  final bool remove;

  /// Al guardar el PIN, activa también la huella (desde «Huella o rostro»).
  final bool thenBiometric;

  @override
  State<_PinForm> createState() => _PinFormState();
}

class _PinFormState extends State<_PinForm> {
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.app;
    final lock = app.lock;
    final nav = Navigator.of(context);
    if (lock.enabled && !lock.check(_current.text)) {
      setState(() => _error = 'El PIN actual no es correcto');
      return;
    }
    if (widget.remove) {
      await lock.disable();
      app.onToast?.call('PIN quitado');
      nav.pop();
      return;
    }
    if (!AppLock.validPin(_pin.text)) {
      setState(() => _error = 'El PIN debe tener de 4 a 6 dígitos');
      return;
    }
    if (_pin.text != _repeat.text) {
      setState(() => _error = 'Los PIN no coinciden');
      return;
    }
    await lock.setPin(_pin.text);
    nav.pop();
    if (widget.thenBiometric && await enableBiometrics(lock)) {
      app.onToast?.call('Listo: abre Alvea con tu huella (o con el PIN)');
    } else {
      app.onToast?.call('PIN guardado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.app.lock;
    final digits = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];
    return Stack12(
      children: [
        if (!widget.remove)
          Text(
            'Solo se guarda en este dispositivo. Si lo olvidas, cierra sesión y vuelve a entrar con tu contraseña.',
            style: CrText.caption(context.c.inkMuted),
          ),
        if (lock.enabled)
          CrTextField(
            label: 'PIN actual',
            controller: _current,
            obscure: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            autofocus: true,
            onSubmitted: (_) => widget.remove ? _submit() : null,
          ),
        if (!widget.remove) ...[
          CrTextField(
            label: 'PIN nuevo (4 a 6 dígitos)',
            controller: _pin,
            obscure: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            autofocus: !lock.enabled,
          ),
          CrTextField(
            label: 'Repite el PIN',
            controller: _repeat,
            obscure: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            onSubmitted: (_) => _submit(),
          ),
        ],
        ErrorText(_error),
        CrButton(
          variant: widget.remove ? CrButtonVariant.danger : CrButtonVariant.primary,
          label: widget.remove ? 'Quitar PIN' : 'Guardar PIN',
          expand: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}
